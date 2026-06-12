import UIKit

// Lex iOS keyboard extension.
//
// Adapts the macOS app's idea (engine-driven synthetic-backspace + replacement
// reconciliation, with liblex as the single source of truth) to a custom
// keyboard. There is no CGEventTap here: the extension *is* the keyboard, so it
// reconciles against the host text field through UITextDocumentProxy
// (insertText / deleteBackward) instead of synthesising key events.
//
// File layout:
//   - LexEngine            : thin Swift wrapper over the liblex C ABI.
//   - KeyboardViewController: UIInputViewController principal class; owns the
//                             engine and the tap-to-text reconciliation logic.
//   - KeyboardView          : from-scratch UIKit US-QWERTY UI (3 planes).

// MARK: - Engine wrapper

// Thin wrapper over the liblex C ABI. Pure C interop, no UIKit; mirrors the
// macOS app's LexEngine so the proven behaviour carries over verbatim.
private final class LexEngine {
    // The internal state of the engine. DO NOT READ.
    private let state: UnsafeMutableRawPointer
    // The memory to receive the replacement characters from engine.
    private var replacement_buffer: [UInt16] = [UInt16](
        repeating: 0,
        count: Int(lex_replacement_buffer_length)
    )
    // The memory to receive the number of replacement characters from engine.
    private var replacement_count: UInt8 = 0

    init() {
        let byte_count = Int(lex_state_size)
        let alignment = Int(lex_state_alignment)
        let state = UnsafeMutableRawPointer.allocate(
            byteCount: byte_count,
            alignment: alignment
        )
        lex_init(state)
        self.state = state
    }

    deinit {
        self.state.deallocate()
    }

    func reset() {
        lex_init(self.state)
    }

    func add(_ unicode_scalar: Unicode.Scalar) {
        guard unicode_scalar.isASCII else {
            return
        }
        lex_add(self.state, UInt8(unicode_scalar.value))
    }

    func backspace() {
        if !self.buffer_empty() {
            lex_backspace(self.state)
        }
    }

    func buffer_full() -> Bool {
        return lex_buffer_full(self.state)
    }

    func buffer_empty() -> Bool {
        return lex_buffer_empty(self.state)
    }

    func buffer_effective_full() -> Bool {
        return lex_buffer_effective_full(self.state)
    }

    func synthetic_backspaces() -> Int {
        return Int(lex_calculate_synthetic_backspaces(self.state))
    }

    // Compose the current replacement string. The closure is only invoked when
    // the engine produced at least one character.
    func compose_replacement(_ body: (UnsafeBufferPointer<UInt16>) -> Void) {
        self.replacement_count = 0
        lex_compose_utf16_string_replacement(
            self.state,
            &self.replacement_buffer,
            &self.replacement_count
        )
        let count = Int(self.replacement_count)
        guard count > 0 else {
            return
        }
        self.replacement_buffer.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else {
                return
            }
            body(UnsafeBufferPointer(start: base, count: count))
        }
    }
}

// MARK: - Keyboard view controller (principal class)

private final class KeyboardInputView: UIInputView {
    weak var keyboard_view: KeyboardView?

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.bounds.contains(point)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard self.point(inside: point, with: event) else {
            return nil
        }

        if let keyboard_view = self.keyboard_view {
            let point_in_keyboard = keyboard_view.convert(point, from: self)
            if keyboard_view.point(inside: point_in_keyboard, with: event) {
                return keyboard_view
            }
        }

        return super.hitTest(point, with: event)
    }
}

final class KeyboardViewController: UIInputViewController {
    // Fixed portrait-iPhone keyboard height (v1 scope: portrait only).
    private static let keyboard_height: CGFloat = 216

    private let engine = LexEngine()

    // The text we believe sits immediately before the cursor (the engine's
    // currently composed word). Used as a guardrail to detect external changes
    // (cursor moves, host edits): if the document no longer ends with this, the
    // world changed under us and we start a fresh composition.
    private var owned_suffix: String = ""

    private let keyboard_view = KeyboardView()

    // Cached traits, to avoid rebuilding the keyboard on every keystroke.
    private var applied_dark: Bool?
    private var applied_return_content: ReturnKeyContent?
    private var applied_shows_globe: Bool?
    private var applied_document_identifier: UUID?

    // Provide the controller's root input view. We use a UIInputView subclass
    // only to route touches through our no-gap hit grid; the keyboard width is
    // owned by the system and the height is set by the Auto Layout constraint in
    // viewDidLoad.
    override func loadView() {
        let input_view = KeyboardInputView(
            frame: CGRect(x: 0, y: 0, width: 0, height: Self.keyboard_height),
            inputViewStyle: .keyboard
        )
        input_view.isMultipleTouchEnabled = true
        input_view.allowsSelfSizing = false

        self.view = input_view
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // The owned suffix only ever holds the engine's current composition, so
        // reserve once up front and clear it in place (keeping capacity) on every
        // reset to avoid reallocating the backing storage during typing.
        self.owned_suffix.reserveCapacity(Int(lex_replacement_buffer_length))

        self.keyboard_view.translatesAutoresizingMaskIntoConstraints = false
        self.keyboard_view.delegate = self
        if let input_view = self.view as? KeyboardInputView {
            input_view.keyboard_view = self.keyboard_view
        }
        self.view.addSubview(self.keyboard_view)

        // Set the keyboard height with an Auto Layout constraint on the root
        // view, the documented way to size a custom keyboard. Priority < required
        // (1000) avoids conflicting with the host's own required encapsulated-
        // layout-height during transitions.
        let height_constraint = self.view.heightAnchor.constraint(
            equalToConstant: Self.keyboard_height
        )
        height_constraint.priority = UILayoutPriority(999)

        NSLayoutConstraint.activate([
            self.keyboard_view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.keyboard_view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.keyboard_view.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.keyboard_view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            height_constraint,
        ])

        self.refresh_traits(force: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.keyboard_view.cancel_tracking()
        // Fresh document / re-presentation: start a clean composition.
        self.reset_composition()
        self.applied_document_identifier = self.textDocumentProxy.documentIdentifier
        // Re-presentation (app foreground, keyboard switch) must not tear down
        // the UI when nothing changed. The trait cache still applies any real
        // change (appearance, return title, globe) as a cheap in-place update.
        self.refresh_traits(force: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.keyboard_view.cancel_tracking()
    }

    // The host text/selection changed. We do NOT reset here: this fires for our
    // own edits too, and resetting would break multi-key Telex composition.
    // Reset only when the active document identity changes; destructive edit
    // guards still validate the owned suffix before deleting host text.
    override func textDidChange(_ textInput: UITextInput?) {
        let document_identifier = self.textDocumentProxy.documentIdentifier
        if document_identifier != self.applied_document_identifier {
            self.applied_document_identifier = document_identifier
            self.reset_composition()
        }
        self.refresh_traits(force: false)
    }

    // MARK: Reconciliation

    // Drop the current composition: clear the engine and the owned-suffix model.
    // The string is emptied in place so the capacity reserved in viewDidLoad
    // survives across resets.
    private func reset_composition() {
        self.engine.reset()
        self.owned_suffix.removeAll(keepingCapacity: true)
    }

    // Detect host edits that happened outside our control while the document
    // identity stayed the same — the field being cleared after a send, or the
    // caret being moved by a tap. textDidChange cannot distinguish these from our
    // own edits, so we check here, at the start of a fresh key, where any prior
    // edit of ours has fully settled: if the text before the caret no longer ends
    // with the word we believe we composed, the world changed and we start over.
    private func reconcile_external_change() {
        guard !self.owned_suffix.isEmpty else {
            return
        }
        let before = self.textDocumentProxy.documentContextBeforeInput ?? ""
        if !before.hasSuffix(self.owned_suffix) {
            self.reset_composition()
        }
    }

    private func handle_character(_ text: String) {
        self.reconcile_external_change()

        let proxy = self.textDocumentProxy

        // Only ASCII letters flow through the engine. Everything else (digits,
        // symbols) is inserted verbatim and ends the current composition.
        let scalars = text.unicodeScalars
        let is_single_ascii_alpha: Bool = {
            guard text.count == 1, scalars.count == 1, let v = scalars.first?.value else {
                return false
            }
            return (v >= 65 && v <= 90) || (v >= 97 && v <= 122)
        }()

        guard is_single_ascii_alpha, let scalar = scalars.first else {
            self.reset_composition()
            proxy.insertText(text)
            return
        }

        if self.engine.buffer_full() {
            self.reset_composition()
        }

        if self.engine.buffer_effective_full() {
            // No room left to compose; append literally but keep the engine in
            // sync so backspace tracking stays correct.
            self.engine.add(scalar)
            proxy.insertText(text)
            self.owned_suffix += text
            return
        }

        // Normal path: feed the engine, then mirror its delete/insert against
        // both the host document and the owned-suffix model. liblex returns the
        // tail segment from its modification index (e.g. "nuowc" -> "ươc") plus
        // the count of previously committed characters to drop, so the visible
        // text becomes owned_suffix.dropLast(backspaces) + composed.
        self.engine.add(scalar)
        let backspaces = self.engine.synthetic_backspaces()

        // Host context reads cross the keyboard/host boundary, so keep them out
        // of the append-only hot path. Validate only before destructive edits,
        // where a stale suffix would otherwise delete text we do not own.
        if backspaces > 0, !self.owned_suffix.isEmpty {
            let before = proxy.documentContextBeforeInput ?? ""
            if !before.hasSuffix(self.owned_suffix) {
                self.reset_composition()
                proxy.insertText(text)
                return
            }
        }

        var composed = ""
        self.engine.compose_replacement { buffer in
            composed = String(utf16CodeUnits: buffer.baseAddress!, count: buffer.count)
        }

        // Fail safe: never delete host text we cannot account for. If the engine
        // produced no replacement, or asks to drop more than we own, reset and
        // insert the key literally rather than corrupting the document.
        guard !composed.isEmpty, self.remove_owned_suffix_chars(backspaces) else {
            self.reset_composition()
            proxy.insertText(text)
            return
        }

        for _ in 0..<backspaces {
            proxy.deleteBackward()
        }
        proxy.insertText(composed)
        self.owned_suffix += composed
    }

    // Drop `count` characters from the owned-suffix model, mirroring the
    // synthetic backspaces sent to the document. Returns false (without
    // mutating) when we do not own that many characters — a desync signal.
    private func remove_owned_suffix_chars(_ count: Int) -> Bool {
        guard count >= 0, count <= self.owned_suffix.count else {
            return false
        }
        for _ in 0..<count {
            self.owned_suffix.removeLast()
        }
        return true
    }

    private func handle_backspace() {
        self.reconcile_external_change()
        self.engine.backspace()
        self.textDocumentProxy.deleteBackward()
        if !self.owned_suffix.isEmpty {
            self.owned_suffix.removeLast()
        }
    }

    private func handle_space() {
        self.reset_composition()
        self.textDocumentProxy.insertText(" ")
    }

    private func handle_return() {
        self.reset_composition()
        self.textDocumentProxy.insertText("\n")
    }

    // MARK: Traits

    private func refresh_traits(force: Bool) {
        let dark = self.is_dark_appearance()
        let return_content = self.return_key_content()
        let shows_globe = self.needsInputModeSwitchKey

        if !force,
            dark == self.applied_dark,
            return_content == self.applied_return_content,
            shows_globe == self.applied_shows_globe
        {
            return
        }

        self.applied_dark = dark
        self.applied_return_content = return_content
        self.applied_shows_globe = shows_globe

        self.keyboard_view.apply_traits(
            dark: dark,
            shows_globe: shows_globe,
            return_content: return_content
        )
    }

    private func is_dark_appearance() -> Bool {
        switch self.textDocumentProxy.keyboardAppearance {
        case .dark:
            return true
        case .light:
            return false
        default:
            return self.traitCollection.userInterfaceStyle == .dark
        }
    }

    // Resolve the host's returnKeyType into what the return key should display.
    // Search/Go/Enter render as SF Symbols to match the iOS system keyboard; the
    // remaining types keep their text labels (the system keyboard shows text for
    // those too). The label strings double as VoiceOver labels for the icons.
    private func return_key_content() -> ReturnKeyContent {
        switch self.textDocumentProxy.returnKeyType {
        case .go:
            return .symbol(name: "arrow.forward", label: "go")
        case .google, .yahoo, .search:
            return .symbol(name: "magnifyingglass", label: "search")
        case .send:
            return .text("Send")
        case .next:
            return .text("Next")
        case .done:
            return .text("Done")
        case .continue:
            return .text("Continue")
        case .join:
            return .text("Join")
        case .route:
            return .text("Route")
        case .emergencyCall:
            return .text("Emergency Call")
        case .default:
            return .symbol(name: "return", label: "return")
        @unknown default:
            return .symbol(name: "return", label: "return")
        }
    }
}

extension KeyboardViewController: KeyboardViewDelegate {
    fileprivate func keyboard_view(_ view: KeyboardView, didEmit action: KeyAction) {
        switch action {
        case .character(let text):
            self.handle_character(text)
        case .backspace:
            self.handle_backspace()
        case .space:
            self.handle_space()
        case .enter:
            self.handle_return()
        case .nextKeyboard:
            self.advanceToNextInputMode()
        case .shift, .plane:
            // UI-only state, handled inside KeyboardView.
            break
        }
    }
}

// MARK: - Keyboard UI model

private enum KeyAction {
    case character(String)
    case backspace
    case shift
    case space
    case enter
    case nextKeyboard
    case plane(KeyPlane)
}

private enum KeyPlane {
    case letters, numbers, symbols
}

// Granularity of a pending keyboard-view update. A structural change alters the
// button set or their widths (plane switch, globe show/hide, first build) and
// requires rebuilding the view tree and re-laying out. An in-place change only
// alters the content or colors of the existing buttons (shift case, return
// content, dark/light) and reuses the buttons, frames and hit frames. `structural`
// supersedes `in_place` when both are requested before the next apply.
private enum PendingUpdate {
    case none, in_place, structural
}

private enum KeyWidth {
    case unit
    case fill
    case ratio(CGFloat)
}

private enum KeyStyle {
    case letter
    case function
}

// What a key displays and emits as a function of dynamic state. The stable
// structure (which key sits where, its width and style) lives in KeySpec; only
// the displayed content (shift case, return label/icon) varies with live
// KeyboardView state, resolved via resolve_content(for:).
private enum KeyKind {
    // An ASCII letter key. Carries the precomputed lower/upper title strings so
    // no case conversion or allocation happens while typing.
    case letter(lower: String, upper: String)
    // A key whose text never changes (number/symbol keys, the "." key, the
    // plane-switch keys 123/ABC/#+=).
    case text(String)
    // A key that always renders the same SF Symbol (backspace, globe). The label
    // is the VoiceOver description.
    case symbol(name: String, label: String)
    // The spacebar: visually blank, VoiceOver label "space".
    case space
    // The shift key: SF Symbol derived from the live shift state.
    case shift
    // The return key: content derived from the host-provided return descriptor.
    case enter
}

// The resolved visual content of a key for the current state: text, an SF
// Symbol image, or visually blank. Behavior is owned by KeyAction; this only
// describes what to draw. Symbol and blank carry an explicit VoiceOver label
// because they have no title text to read.
private enum KeyContent {
    case text(String)
    case symbol(name: String, label: String)
    case blank(label: String)
}

// What the return key should display, resolved by the controller from the
// host's returnKeyType. Equatable so the trait cache can detect changes without
// comparing UIImage instances.
private enum ReturnKeyContent: Equatable {
    case symbol(name: String, label: String)
    case text(String)
}

// Immutable description of a key's position-independent identity. Built once
// into the static plane templates; reused for the lifetime of the keyboard.
private struct KeySpec {
    let action: KeyAction
    let kind: KeyKind
    let width: KeyWidth
    let style: KeyStyle
}

private enum ShiftState {
    case off, on, locked
}

private final class KeyButton: UIButton {
    var spec: KeySpec!
    var hit_frame: CGRect?

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let hit_frame = self.hit_frame, let superview = self.superview else {
            return super.point(inside: point, with: event)
        }
        let point_in_keyboard = self.convert(point, to: superview)
        return hit_frame.contains(point_in_keyboard)
    }
}

private protocol KeyboardViewDelegate: AnyObject {
    func keyboard_view(_ view: KeyboardView, didEmit action: KeyAction)
}

private struct ActiveTouch {
    let button: KeyButton
    var inside: Bool
}

// MARK: - Keyboard UI

private final class KeyboardView: UIView {
    private static let trigger_cell_overlap: CGFloat = 2
    private static let backspace_initial_repeat_delay: TimeInterval = 0.32
    private static let backspace_repeat_interval: TimeInterval = 0.055

    // Visual metrics matching the iOS system keyboard. These are the single
    // calibration point for label/icon sizing; tune against a same-device,
    // same-appearance screenshot diff (iPhone 11 Pro portrait, iOS 26). SF
    // Symbol point size is not a visible-height guarantee, so a symbol may still
    // need a per-glyph tweak if it reads optically larger/smaller than the rest.
    private static let letter_font = UIFont.systemFont(ofSize: 25, weight: .regular)
    private static let function_font = UIFont.systemFont(ofSize: 18, weight: .regular)
    private static let symbol_config = UIImage.SymbolConfiguration(
        pointSize: 20,
        weight: .regular
    )

    weak var delegate: KeyboardViewDelegate?

    // Controller-driven state.
    var shows_globe: Bool = false
    var return_content: ReturnKeyContent = .symbol(name: "return", label: "return")

    // UI-only state.
    private var plane: KeyPlane = .letters
    private var shift_state: ShiftState = .off
    private var is_dark: Bool = false
    private var last_shift_tap: TimeInterval = 0
    private var backspace_timer: Timer?
    private var repeating_backspace_touch: ObjectIdentifier?

    // The currently visible, routable buttons (active plane, globe filtered by
    // shows_globe). Layout and touch routing iterate this and nothing else, so
    // hidden planes and the unused globe never receive frames or touches.
    private var rows: [[KeyButton]] = []
    // Every button for all three planes, built once. Prebuilding front-loads all
    // allocation: a plane switch only retargets `rows` and toggles isHidden, with
    // no view-tree teardown or per-switch allocation.
    private var plane_rows: [KeyPlane: [[KeyButton]]] = [:]
    private var all_buttons: [KeyButton] = []
    private var active_touches: [ObjectIdentifier: ActiveTouch] = [:]
    private var pending_update: PendingUpdate = .none
    // The button tree is built lazily once the controller has supplied the
    // resolved traits (appearance, return title, globe), so the first paint is
    // already correct instead of flashing a default-light layout then
    // recolouring. Until then there are no buttons to update in place.
    private var did_build = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        // Fast iPhone typing often overlaps touches (for example, the next
        // thumb lands before the previous one fully lifts). UIKit views and
        // controls default to single-touch tracking, which can drop that second
        // key before it reaches the delegate. Keep both the keyboard container
        // and every key multi-touch capable so independent key presses are not
        // filtered by UIKit before our reconciliation code runs.
        self.isMultipleTouchEnabled = true
        self.isOpaque = false
        // Keep a nearly transparent backing color. A fully transparent custom
        // keyboard surface can leave UIKit routing touches only to visible
        // subviews in the visual gaps, before our no-gap grid router runs. The
        // colour is appearance-independent, so it is set once here rather than
        // on every trait change. The first button build is deferred until the
        // controller pushes resolved traits via apply_traits.
        self.backgroundColor = UIColor(white: 0, alpha: 0.001)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.backspace_timer?.invalidate()
    }

    // Controller entry point for resolved traits. Decides the cheapest update
    // that reproduces the previous full-rebuild result: the first call (or a
    // globe show/hide, which changes the bottom-row button set) is structural;
    // a return-content or appearance change only needs an in-place refresh.
    func apply_traits(dark: Bool, shows_globe: Bool, return_content: ReturnKeyContent) {
        let structural_change = shows_globe != self.shows_globe
        let needs_update =
            !self.did_build
            || structural_change
            || dark != self.is_dark
            || return_content != self.return_content

        self.is_dark = dark
        self.shows_globe = shows_globe
        self.return_content = return_content

        guard needs_update else {
            return
        }

        if !self.did_build || structural_change {
            self.request_update(.structural)
        } else {
            self.request_update(.in_place)
        }
    }

    // Schedule an update. In-place updates only retitle/recolor existing buttons
    // (never add, remove or move them), so they are safe mid-touch and applied
    // immediately for instant feedback — holding shift capitalizes the letters
    // right away instead of waiting for release. Structural updates change the
    // visible button set and their frames, so they are deferred while any finger
    // is tracking (to avoid pulling a button out from under a touch) and flushed
    // once tracking goes idle. A pending structural is preserved across in-place
    // updates and still flushes later.
    private func request_update(_ kind: PendingUpdate) {
        switch kind {
        case .none:
            break
        case .in_place:
            self.refresh_in_place()
        case .structural:
            if self.active_touches.isEmpty {
                self.rebuild_structure()
            } else {
                self.pending_update = .structural
            }
        }
    }

    private func apply_update(_ kind: PendingUpdate) {
        switch kind {
        case .structural:
            self.rebuild_structure()
        case .in_place:
            self.refresh_in_place()
        case .none:
            break
        }
    }

    // Structural update: switches which prebuilt plane is visible (plane switch,
    // globe show/hide, first build) and re-lays it out. The first call builds all
    // three planes once; later calls only retarget `rows` and toggle visibility,
    // so no button is ever created or destroyed after launch. Resets backspace
    // auto-repeat as the old reload did; this only runs while idle, so no held
    // backspace is in flight.
    private func rebuild_structure() {
        self.backspace_timer?.invalidate()
        self.backspace_timer = nil
        self.repeating_backspace_touch = nil
        self.pending_update = .none

        if !self.did_build {
            self.build_all_planes()
            self.did_build = true
        }

        self.activate_current_plane()
    }

    // Build every plane's buttons once and add them all as hidden subviews. This
    // is the single allocation point for the button tree.
    private func build_all_planes() {
        for plane in [KeyPlane.letters, .numbers, .symbols] {
            let rows = Self.template(for: plane).map { row in
                row.map { spec in self.make_button(spec) }
            }
            self.plane_rows[plane] = rows
            for row in rows {
                for button in row {
                    button.isHidden = true
                    self.addSubview(button)
                    self.all_buttons.append(button)
                }
            }
        }
    }

    // Point `rows` at the active plane (dropping the globe key when the host
    // supplies its own input-mode switcher), show only those buttons, refresh
    // their titles/colors from current state, and request a relayout. Runs only
    // while idle, so clearing highlights here cannot strand a pressed key.
    private func activate_current_plane() {
        for button in self.all_buttons {
            button.isHighlighted = false
            button.isHidden = true
        }

        guard var rows = self.plane_rows[self.plane] else {
            return
        }
        if !self.shows_globe, let globe = self.globe_button(in: self.plane) {
            rows[rows.count - 1] = rows[rows.count - 1].filter { $0 !== globe }
        }
        self.rows = rows

        for row in self.rows {
            for button in row {
                button.isHidden = false
            }
        }

        UIView.performWithoutAnimation {
            self.style_active_buttons()
        }
        self.setNeedsLayout()
    }

    // In-place update: reuses the visible buttons, refreshing only their titles
    // and colors. The structure (button set and widths) is unchanged for the
    // cases that route here (shift case, return title, dark/light), so frames and
    // hit frames stay valid and no relayout of the grid is needed. Runs only
    // while idle, so no button is highlighted and the backspace timer is
    // untouched. If the tree was never built, fall back to a structural build.
    private func refresh_in_place() {
        // Do not touch pending_update here: only structural updates are ever
        // deferred, and an in-place refresh must not discard one waiting to flush.
        guard self.did_build else {
            self.rebuild_structure()
            return
        }

        // Title/color changes on a UIButton can crossfade inside a transition
        // context (keyboard presentation is one); the old full rebuild showed
        // fresh buttons with no animation, so keep these updates immediate.
        UIView.performWithoutAnimation {
            self.style_active_buttons()
            self.layoutIfNeeded()
        }
    }

    // Refresh the title and colors of every currently visible button from live
    // state. Only the active plane is touched; hidden planes are restyled when
    // they next become active, so they are never visibly stale.
    private func style_active_buttons() {
        for row in self.rows {
            for button in row {
                self.render_content(button)
                self.apply_colors(to: button)
            }
        }
    }

    private func globe_button(in plane: KeyPlane) -> KeyButton? {
        return self.plane_rows[plane]?.last?.first { button in
            if case .nextKeyboard = button.spec.action {
                return true
            }
            return false
        }
    }

    // The displayed content for a key, derived from current shift/return state.
    // Letters/text resolve to a string; shift, backspace and globe to SF
    // Symbols; the spacebar to blank; the return key follows the host descriptor.
    private func resolve_content(for spec: KeySpec) -> KeyContent {
        switch spec.kind {
        case .letter(let lower, let upper):
            return .text(self.shift_state == .off ? lower : upper)
        case .text(let display):
            return .text(display)
        case .symbol(let name, let label):
            return .symbol(name: name, label: label)
        case .space:
            return .blank(label: "space")
        case .shift:
            switch self.shift_state {
            case .off:
                return .symbol(name: "shift", label: "shift")
            case .on:
                return .symbol(name: "shift.fill", label: "shift")
            case .locked:
                return .symbol(name: "capslock.fill", label: "caps lock")
            }
        case .enter:
            switch self.return_content {
            case .symbol(let name, let label):
                return .symbol(name: name, label: label)
            case .text(let text):
                return .text(text)
            }
        }
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.bounds.insetBy(
            dx: -Self.trigger_cell_overlap,
            dy: -Self.trigger_cell_overlap
        ).contains(point)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard self.point(inside: point, with: event) else {
            return nil
        }
        return self
    }

    override func draw(_ rect: CGRect) {
        // Keep a backing store over the full keyboard bounds. The router maps
        // all gap touches to the intended key partitions.
        UIColor(white: 0, alpha: 0.001).setFill()
        UIRectFill(rect)
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        let edge: CGFloat = 6.5
        let gap: CGFloat = 6
        let top_inset: CGFloat = 8
        let bottom_inset = max(self.safeAreaInsets.bottom, 4)
        let row_gap: CGFloat = 11
        let width = self.bounds.width

        guard width > 0, self.rows.count == 4 else {
            return
        }

        let available_height = self.bounds.height - top_inset - bottom_inset
        let row_height = (available_height - row_gap * 3) / 4
        // Key unit derived from the 10-key top row so every letter key matches
        // the system keyboard's width and narrower rows centre naturally.
        let key_unit = (width - 2 * edge - 9 * gap) / 10

        for (index, row) in self.rows.enumerated() {
            let y = top_inset + CGFloat(index) * (row_height + row_gap)
            self.layout_row(
                row,
                y: y,
                row_height: row_height,
                key_unit: key_unit,
                gap: gap,
                edge: edge,
                total_width: width
            )
        }

        self.layout_hit_frames()
    }

    private func resolved_width(_ width: KeyWidth, key_unit: CGFloat) -> CGFloat? {
        switch width {
        case .unit:
            return key_unit
        case .ratio(let ratio):
            return key_unit * ratio
        case .fill:
            return nil
        }
    }

    private func layout_row(
        _ row: [KeyButton],
        y: CGFloat,
        row_height: CGFloat,
        key_unit: CGFloat,
        gap: CGFloat,
        edge: CGFloat,
        total_width: CGFloat
    ) {
        var fixed_sum: CGFloat = 0
        var fill_count = 0
        for button in row {
            if let resolved = self.resolved_width(button.spec.width, key_unit: key_unit) {
                fixed_sum += resolved
            } else {
                fill_count += 1
            }
        }

        let total_gap = gap * CGFloat(max(row.count - 1, 0))
        let row_available = total_width - 2 * edge

        var fill_width: CGFloat = 0
        if fill_count > 0 {
            fill_width = max((row_available - fixed_sum - total_gap) / CGFloat(fill_count), key_unit)
        }

        // Rows with a fill key start at the edge and span the width; rows
        // without (the letter rows) are centred so row 2 indents like iOS.
        var x: CGFloat = (fill_count > 0) ? edge : (total_width - (fixed_sum + total_gap)) / 2

        for button in row {
            let button_width = self.resolved_width(button.spec.width, key_unit: key_unit) ?? fill_width
            button.frame = CGRect(x: x, y: y, width: button_width, height: row_height)
            x += button_width + gap
        }
    }

    private func layout_hit_frames() {
        for (row_index, row) in self.rows.enumerated() {
            guard !row.isEmpty else {
                continue
            }

            let row_top: CGFloat
            if row_index == 0 {
                row_top = self.bounds.minY
            } else {
                let previous_row = self.rows[row_index - 1]
                row_top = (previous_row[0].frame.maxY + row[0].frame.minY) / 2
            }

            let row_bottom: CGFloat
            if row_index == self.rows.count - 1 {
                row_bottom = self.bounds.maxY
            } else {
                let next_row = self.rows[row_index + 1]
                row_bottom = (row[0].frame.maxY + next_row[0].frame.minY) / 2
            }

            for (button_index, button) in row.enumerated() {
                let hit_left: CGFloat
                if button_index == 0 {
                    hit_left = self.bounds.minX
                } else {
                    let previous_button = row[button_index - 1]
                    hit_left = (previous_button.frame.maxX + button.frame.minX) / 2
                }

                let hit_right: CGFloat
                if button_index == row.count - 1 {
                    hit_right = self.bounds.maxX
                } else {
                    let next_button = row[button_index + 1]
                    hit_right = (button.frame.maxX + next_button.frame.minX) / 2
                }

                button.hit_frame = CGRect(
                    x: hit_left,
                    y: row_top,
                    width: hit_right - hit_left,
                    height: row_bottom - row_top
                )
            }
        }
    }

    // MARK: Touch routing

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Order overlapping presses by timestamp so fast two-thumb input reaches
        // the delegate in the order it happened. A single touch needs no sort,
        // so skip the array allocation on the common path.
        if touches.count > 1 {
            for touch in touches.sorted(by: { $0.timestamp < $1.timestamp }) {
                self.begin_tracking(touch)
            }
        } else {
            for touch in touches {
                self.begin_tracking(touch)
            }
        }
    }

    private func begin_tracking(_ touch: UITouch) {
        let point = touch.location(in: self)
        guard let button = self.key_button(at: point) else {
            return
        }

        let touch_id = ObjectIdentifier(touch)
        self.active_touches[touch_id] = ActiveTouch(button: button, inside: true)
        button.isHighlighted = true
        self.key_touch_down(button, touch_id: touch_id)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let touch_id = ObjectIdentifier(touch)
            guard var active_touch = self.active_touches[touch_id] else {
                continue
            }

            let point = touch.location(in: self)
            let inside = self.point(point, inside: active_touch.button)
            if inside != active_touch.inside {
                active_touch.inside = inside
                active_touch.button.isHighlighted = inside
                self.active_touches[touch_id] = active_touch

                if !inside, case .backspace = active_touch.button.spec.action {
                    self.stop_backspace_repeat(touch_id: touch_id)
                }
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let touch_id = ObjectIdentifier(touch)
            guard let active_touch = self.active_touches.removeValue(forKey: touch_id) else {
                continue
            }

            active_touch.button.isHighlighted = false

            if case .backspace = active_touch.button.spec.action {
                self.stop_backspace_repeat(touch_id: touch_id)
            }
        }

        self.flush_pending_update_if_idle()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let touch_id = ObjectIdentifier(touch)
            guard let active_touch = self.active_touches.removeValue(forKey: touch_id) else {
                continue
            }

            active_touch.button.isHighlighted = false
            if case .backspace = active_touch.button.spec.action {
                self.stop_backspace_repeat(touch_id: touch_id)
            }
        }

        self.flush_pending_update_if_idle()
    }

    private func key_button(at point: CGPoint) -> KeyButton? {
        self.layoutIfNeeded()

        guard !self.rows.isEmpty, !self.bounds.isEmpty else {
            return nil
        }

        let bounded_point = CGPoint(
            x: min(max(point.x, self.bounds.minX), self.bounds.maxX),
            y: min(max(point.y, self.bounds.minY), self.bounds.maxY)
        )

        guard let row = self.row(at: bounded_point.y) else {
            return nil
        }

        return self.button(in: row, at: bounded_point.x)
    }

    private func row(at y: CGFloat) -> [KeyButton]? {
        var best_row: [KeyButton]?
        var best_distance = CGFloat.greatestFiniteMagnitude

        for row in self.rows {
            guard let frame = row.first?.hit_frame else {
                continue
            }

            let expanded_frame = frame.insetBy(dx: 0, dy: -Self.trigger_cell_overlap)
            if y >= expanded_frame.minY, y <= expanded_frame.maxY {
                return row
            }

            let distance = abs(y - frame.midY)
            if distance < best_distance {
                best_distance = distance
                best_row = row
            }
        }

        return best_row
    }

    private func button(in row: [KeyButton], at x: CGFloat) -> KeyButton? {
        var best_button: KeyButton?
        var best_distance = CGFloat.greatestFiniteMagnitude

        for button in row {
            guard let frame = button.hit_frame else {
                continue
            }

            let expanded_frame = frame.insetBy(dx: -Self.trigger_cell_overlap, dy: 0)
            if x >= expanded_frame.minX, x <= expanded_frame.maxX {
                return button
            }

            let distance = abs(x - frame.midX)
            if distance < best_distance {
                best_distance = distance
                best_button = button
            }
        }

        return best_button
    }

    private func point(_ point: CGPoint, inside button: KeyButton) -> Bool {
        let frame = button.hit_frame ?? button.frame
        let expanded_frame = frame.insetBy(
            dx: -Self.trigger_cell_overlap,
            dy: -Self.trigger_cell_overlap
        )
        return point.x >= expanded_frame.minX
            && point.x <= expanded_frame.maxX
            && point.y >= expanded_frame.minY
            && point.y <= expanded_frame.maxY
    }

    private func flush_pending_update_if_idle() {
        if self.active_touches.isEmpty, self.pending_update != .none {
            self.apply_update(self.pending_update)
        }
    }

    func cancel_tracking() {
        self.backspace_timer?.invalidate()
        self.backspace_timer = nil
        self.repeating_backspace_touch = nil

        for active_touch in self.active_touches.values {
            active_touch.button.isHighlighted = false
        }
        self.active_touches.removeAll()

        if self.pending_update != .none {
            self.apply_update(self.pending_update)
        }
    }

    // MARK: Model

    // Stable per-plane layout, computed once. Only the title text (shift case,
    // return label) and colors vary at runtime; the key set, widths and styles
    // here never change, so this allocates exactly once for the process.
    private static func template(for plane: KeyPlane) -> [[KeySpec]] {
        switch plane {
        case .letters:
            return [
                ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"].map(letter_spec),
                ["a", "s", "d", "f", "g", "h", "j", "k", "l"].map(letter_spec),
                [shift_spec]
                    + ["z", "x", "c", "v", "b", "n", "m"].map(letter_spec)
                    + [backspace_spec],
                bottom_row(plane_key: plane_spec(.numbers, "123", width: .ratio(1.4))),
            ]

        case .numbers:
            return [
                ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map(symbol_spec),
                ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""].map(symbol_spec),
                [plane_spec(.symbols, "#+=", width: .fill)]
                    + [".", ",", "?", "!", "'"].map(symbol_spec)
                    + [backspace_spec],
                bottom_row(plane_key: plane_spec(.letters, "ABC", width: .ratio(1.4))),
            ]

        case .symbols:
            return [
                ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="].map(symbol_spec),
                ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"].map(symbol_spec),
                [plane_spec(.numbers, "123", width: .fill)]
                    + [".", ",", "?", "!", "'"].map(symbol_spec)
                    + [backspace_spec],
                bottom_row(plane_key: plane_spec(.letters, "ABC", width: .ratio(1.4))),
            ]
        }
    }

    // The globe (next-keyboard) key occupies the system's emoji slot; it is part
    // of every plane's template but only routed when iOS does not supply its own
    // input-mode switcher (see activate_current_plane). Lex is always Telex, so
    // switching keyboards is how the user types plain Latin / other languages.
    private static func bottom_row(plane_key: KeySpec) -> [KeySpec] {
        return [
            plane_key,
            KeySpec(
                action: .nextKeyboard,
                kind: .symbol(name: "globe", label: "next keyboard"),
                width: .ratio(1.4),
                style: .function
            ),
            KeySpec(action: .space, kind: .space, width: .fill, style: .letter),
            KeySpec(action: .character("."), kind: .text("."), width: .unit, style: .letter),
            KeySpec(action: .enter, kind: .enter, width: .ratio(1.4), style: .function),
        ]
    }

    private static func letter_spec(_ base: String) -> KeySpec {
        return KeySpec(
            action: .character(base),
            kind: .letter(lower: base, upper: base.uppercased()),
            width: .unit,
            style: .letter
        )
    }

    private static func symbol_spec(_ symbol: String) -> KeySpec {
        return KeySpec(action: .character(symbol), kind: .text(symbol), width: .unit, style: .letter)
    }

    private static func plane_spec(_ target: KeyPlane, _ display: String, width: KeyWidth) -> KeySpec {
        return KeySpec(action: .plane(target), kind: .text(display), width: width, style: .function)
    }

    private static let shift_spec = KeySpec(
        action: .shift, kind: .shift, width: .fill, style: .function
    )
    private static let backspace_spec = KeySpec(
        action: .backspace,
        kind: .symbol(name: "delete.left", label: "delete"),
        width: .fill,
        style: .function
    )

    // MARK: Buttons

    private func make_button(_ spec: KeySpec) -> KeyButton {
        let button = KeyButton(type: .system)
        button.spec = spec
        button.isMultipleTouchEnabled = true
        button.isExclusiveTouch = false
        button.layer.cornerRadius = 8
        button.layer.cornerCurve = .continuous
        self.render_content(button)
        self.apply_colors(to: button)
        return button
    }

    // Apply the resolved content to a button: render either a title or an SF
    // Symbol image and always clear the unused representation, so a return-key
    // icon never leaves a stale title behind it (or vice versa). Letters never
    // shrink (single glyph); function text may shrink for long fallback labels
    // such as "Emergency Call". Symbol/blank keys carry an explicit VoiceOver
    // label since they have no title to read.
    private func render_content(_ button: KeyButton) {
        switch self.resolve_content(for: button.spec) {
        case .text(let text):
            button.setImage(nil, for: .normal)
            button.setTitle(text, for: .normal)
            button.accessibilityLabel = nil
            let is_letter = button.spec.style == .letter
            button.titleLabel?.font = is_letter ? Self.letter_font : Self.function_font
            button.titleLabel?.adjustsFontSizeToFitWidth = !is_letter
            button.titleLabel?.minimumScaleFactor = 0.5
        case .symbol(let name, let label):
            button.setTitle(nil, for: .normal)
            button.setImage(
                UIImage(systemName: name, withConfiguration: Self.symbol_config),
                for: .normal
            )
            button.accessibilityLabel = label
        case .blank(let label):
            button.setTitle(nil, for: .normal)
            button.setImage(nil, for: .normal)
            button.accessibilityLabel = label
        }
    }

    // Colors for one appearance. The two palettes are shared constants so a
    // recolor reuses existing UIColor objects instead of allocating per button.
    private struct Palette {
        let letter_bg: UIColor
        let function_bg: UIColor
        let active_bg: UIColor
        let text: UIColor
    }

    private static let light_palette = Palette(
        letter_bg: .white,
        function_bg: UIColor(white: 0.68, alpha: 1),
        active_bg: .white,
        text: .black
    )
    private static let dark_palette = Palette(
        letter_bg: UIColor(white: 0.42, alpha: 1),
        function_bg: UIColor(white: 0.27, alpha: 1),
        active_bg: UIColor(white: 0.62, alpha: 1),
        text: .white
    )

    private func apply_colors(to button: KeyButton) {
        let palette = self.is_dark ? Self.dark_palette : Self.light_palette

        button.setTitleColor(palette.text, for: .normal)
        // SF Symbols render as template images on a .system button; tint them
        // from the same semantic color as titles so icons track light/dark.
        button.tintColor = palette.text

        switch button.spec.style {
        case .letter:
            button.backgroundColor = palette.letter_bg
        case .function:
            if case .shift = button.spec.action, self.shift_state != .off {
                button.backgroundColor = palette.active_bg
            } else {
                button.backgroundColor = palette.function_bg
            }
        }
    }

    // MARK: Actions

    private func key_touch_down(_ sender: KeyButton, touch_id: ObjectIdentifier) {
        switch sender.spec.action {
        case .backspace:
            self.backspace_touch_down(touch_id: touch_id)
        default:
            self.key_pressed(sender)
        }
    }

    private func key_pressed(_ sender: KeyButton) {
        let action = sender.spec.action
        switch action {
        case .plane(let target):
            self.plane = target
            // Plane switch changes the button set and widths: structural.
            self.request_update(.structural)
        case .shift:
            self.handle_shift_tap()
            // Only letter titles and the shift key colour change: in-place.
            self.request_update(.in_place)
        case .character:
            self.delegate?.keyboard_view(
                self,
                didEmit: .character(self.character_text(for: sender))
            )
            // One-shot shift reverts after a letter, like the system keyboard.
            if self.plane == .letters, self.shift_state == .on {
                self.shift_state = .off
                // Only letter titles and the shift key colour change: in-place.
                self.request_update(.in_place)
            }
        default:
            self.delegate?.keyboard_view(self, didEmit: action)
        }
    }

    // The character a key emits. Derived from live shift state for letters (never
    // from the displayed title, which can lag while updates are deferred under a
    // held touch); fixed-title keys emit their literal. Letter keys carry their
    // precomputed lower/upper forms, so this allocates nothing while typing.
    private func character_text(for sender: KeyButton) -> String {
        switch sender.spec.kind {
        case .letter(let lower, let upper):
            return self.shift_state == .off ? lower : upper
        case .text(let text):
            return text
        case .symbol, .space, .shift, .enter:
            return ""
        }
    }

    private func handle_shift_tap() {
        let now = Date.timeIntervalSinceReferenceDate
        if self.shift_state == .locked {
            self.shift_state = .off
        } else if now - self.last_shift_tap < 0.3 {
            self.shift_state = .locked
        } else {
            self.shift_state = (self.shift_state == .on) ? .off : .on
        }
        self.last_shift_tap = now
    }

    private func backspace_touch_down(touch_id: ObjectIdentifier) {
        self.delegate?.keyboard_view(self, didEmit: .backspace)
        self.backspace_timer?.invalidate()
        self.repeating_backspace_touch = touch_id
        // Initial delay, then auto-repeat while held.
        let delay_timer = Timer(
            timeInterval: Self.backspace_initial_repeat_delay,
            repeats: false
        ) { [weak self] _ in
            guard let self, self.repeating_backspace_touch == touch_id else {
                return
            }
            let repeat_timer = Timer(
                timeInterval: Self.backspace_repeat_interval,
                repeats: true
            ) { [weak self] _ in
                guard let self, self.repeating_backspace_touch == touch_id else {
                    return
                }
                self.delegate?.keyboard_view(self, didEmit: .backspace)
            }
            self.backspace_timer = repeat_timer
            RunLoop.main.add(repeat_timer, forMode: .common)
        }
        self.backspace_timer = delay_timer
        RunLoop.main.add(delay_timer, forMode: .common)
    }

    private func stop_backspace_repeat(touch_id: ObjectIdentifier) {
        guard self.repeating_backspace_touch == touch_id else {
            return
        }

        self.backspace_timer?.invalidate()
        self.backspace_timer = nil
        self.repeating_backspace_touch = nil
    }
}

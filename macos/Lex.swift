import AppKit
import Carbon
import ServiceManagement

// Namespace: LEX!
// Use for register hot key.
private let toggle_input_mode_hot_key_id = EventHotKeyID(
    signature: OSType(0x4C455821),
    id: 1
)
private let toggle_keyboard_lock_hot_key_id = EventHotKeyID(
    signature: OSType(0x4C455821),
    id: 2
)
// Tag: LEX!
// Use for identify Lex's synthetic event when processing event tap.
private let synthetic_event_source_user_data: Int64 = 0x4C455821
private let system_wide_accessibility_element = AXUIElementCreateSystemWide()
// Indicate the status of login item registration
private let login_item_registration_attempted_key = "login_item_registration_attempted"

@main
struct LexApp {
    static func main() {
        let application = NSApplication.shared

        let app_delegate = AppDelegate()
        application.delegate = app_delegate

        // Start as MenuBar app.
        // Info.plist already has LSUIElement=true. This is a fallback if
        // the app is launched without that bundle setting.
        application.setActivationPolicy(.accessory)

        application.run()
    }
}

private enum InputMode {
    case literal, telex
}

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
        // Allocate memory for engine state.
        let byte_count = Int(lex_state_size)
        let alignment = Int(lex_state_alignment)
        let state = UnsafeMutableRawPointer.allocate(
            byteCount: byte_count,
            alignment: alignment
        )
        // Initialize the state.
        lex_init(state)
        self.state = state
    }

    deinit {
        // Release the state memory.
        self.state.deallocate()
    }

    func reset() {
        // Reset the engine state to initial value.
        lex_init(self.state)
    }

    func add(_ unicode_scalar: Unicode.Scalar) {
        // TODO: should return error when not ASCII.
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

    func compose_replacement(_ body: (UnsafeBufferPointer<UInt16>) -> Void) {
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
            body(UnsafeBufferPointer(start: buffer.baseAddress!, count: count))
        }
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = LexEngine()
    private var status_item: NSStatusItem?
    private let telex_image: NSImage = {
        guard let image = NSImage(
            systemSymbolName: "pencil",
            accessibilityDescription: "Lex - Telex input"
        ) else {
            fatalError("Missing required system symbol: pencil")
        }
        image.isTemplate = true
        return image
    }()
    private let literal_image: NSImage = {
        guard let image = NSImage(
            systemSymbolName: "pencil.slash",
            accessibilityDescription: "Lex - Literal input"
        ) else {
            fatalError("Missing required system symbol: pencil.slash")
        }
        image.isTemplate = true
        return image
    }()
    private let keyboard_locked_image: NSImage = {
        guard let image = NSImage(
            systemSymbolName: "lock.fill",
            accessibilityDescription: "Lex - Keyboard locked"
        ) else {
            fatalError("Missing required system symbol: lock.fill")
        }
        image.isTemplate = true
        return image
    }()
    private let telex_sound: NSSound = {
        guard let sound = NSSound(named: "Pop") else {
            fatalError("Missing required system sound: Pop")
        }
        return sound
    }()
    private let literal_sound: NSSound = {
        guard let sound = NSSound(named: "Tink") else {
            fatalError("Missing required system sound: Tink")
        }
        return sound
    }()
    private let keyboard_locked_sound: NSSound = {
        guard let sound = NSSound(named: "Purr") else {
            fatalError("Missing required system sound: Purr")
        }
        return sound
    }()

    private var signal_sources: [DispatchSourceSignal] = []
    private var input_mode: InputMode = .telex
    private var keyboard_locked = false
    private var lock_keyboard_item: NSMenuItem?
    private var toggle_input_mode_hot_key_event_handler_ref: EventHandlerRef?
    private var toggle_input_mode_hot_key_ref: EventHotKeyRef?
    private var toggle_keyboard_lock_hot_key_event_handler_ref: EventHandlerRef?
    private var toggle_keyboard_lock_hot_key_ref: EventHotKeyRef?
    private var toggle_keyboard_lock_key_code: CGKeyCode?
    private lazy var toggle_sound: NSSound = self.telex_sound

    private var event_tap: CFMachPort?
    private var event_tap_run_loop_source: CFRunLoopSource?
    private var synthetic_event_source: CGEventSource?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Activated.")
        self.register_login_item()
        self.install_signal_handler(SIGINT)
        self.install_signal_handler(SIGTERM)
        self.initialize_status_item()
        self.initialize_synthetic_event_source()
        self.start_event_tap()
        self.register_input_mode_hot_key()
        self.register_keyboard_lock_hot_key()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("Shutting down...")
        self.unregister_input_mode_hot_key()
        self.unregister_keyboard_lock_hot_key()
        self.stop_event_tap()
        self.destroy_synthetic_event_source()
        self.destroy_status_item()
        self.signal_sources.removeAll()
    }

    private func install_signal_handler(_ signal_number: Int32) {
        signal(signal_number, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: signal_number, queue: .main)
        source.setEventHandler {
            NSApp.terminate(nil)
        }
        source.resume()
        self.signal_sources.append(source)
    }

    private func register_input_mode_hot_key() {
        let self_pointer = Unmanaged.passUnretained(self).toOpaque()
        var event_type = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handler_status = InstallEventHandler(
            GetApplicationEventTarget(),
            handle_input_mode_hot_key,
            1,
            &event_type,
            self_pointer,
            &self.toggle_input_mode_hot_key_event_handler_ref
        )
        guard handler_status == noErr else {
            print("Failed to install input mode hot key event handler: \(handler_status)")
            return
        }

        let input_mode_id = toggle_input_mode_hot_key_id
        let input_mode_status = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(controlKey | optionKey),
            input_mode_id,
            GetApplicationEventTarget(),
            0,
            &self.toggle_input_mode_hot_key_ref
        )
        if input_mode_status != noErr {
            print("Failed to register input mode hot key: \(input_mode_status)")
        }
    }

    private func unregister_input_mode_hot_key() {
        if let toggle_input_mode_hot_key_ref = self.toggle_input_mode_hot_key_ref {
            UnregisterEventHotKey(toggle_input_mode_hot_key_ref)
            self.toggle_input_mode_hot_key_ref = nil
        }

        if let event_handler_ref = self.toggle_input_mode_hot_key_event_handler_ref {
            RemoveEventHandler(event_handler_ref)
            self.toggle_input_mode_hot_key_event_handler_ref = nil
        }
    }

    private func register_keyboard_lock_hot_key() {
        if self.toggle_keyboard_lock_hot_key_event_handler_ref == nil {
            let self_pointer = Unmanaged.passUnretained(self).toOpaque()
            var event_type = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            let handler_status = InstallEventHandler(
                GetApplicationEventTarget(),
                handle_keyboard_lock_hot_key,
                1,
                &event_type,
                self_pointer,
                &self.toggle_keyboard_lock_hot_key_event_handler_ref
            )
            guard handler_status == noErr else {
                print("Failed to install keyboard lock hot key event handler: \(handler_status)")
                return
            }

            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(keyboard_input_source_changed(_:)),
                name: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
                object: nil,
                suspensionBehavior: .deliverImmediately
            )
        }

        guard self.event_tap != nil else {
            return
        }
        guard let key_code = self.current_keyboard_lock_key_code() else {
            if let hot_key_ref = self.toggle_keyboard_lock_hot_key_ref {
                UnregisterEventHotKey(hot_key_ref)
            }
            self.toggle_keyboard_lock_hot_key_ref = nil
            self.toggle_keyboard_lock_key_code = nil
            print("Failed to resolve keyboard lock hot key for the current input source.")
            return
        }
        if self.toggle_keyboard_lock_key_code == key_code &&
                self.toggle_keyboard_lock_hot_key_ref != nil {
            return
        }

        if let hot_key_ref = self.toggle_keyboard_lock_hot_key_ref {
            UnregisterEventHotKey(hot_key_ref)
        }
        self.toggle_keyboard_lock_hot_key_ref = nil
        self.toggle_keyboard_lock_key_code = nil

        let keyboard_lock_id = toggle_keyboard_lock_hot_key_id
        var hot_key_ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(key_code),
            UInt32(controlKey | optionKey | cmdKey),
            keyboard_lock_id,
            GetApplicationEventTarget(),
            0,
            &hot_key_ref
        )
        guard status == noErr, let hot_key_ref else {
            print("Failed to register keyboard lock hot key: \(status)")
            return
        }
        self.toggle_keyboard_lock_hot_key_ref = hot_key_ref
        self.toggle_keyboard_lock_key_code = key_code
    }

    private func unregister_keyboard_lock_hot_key() {
        DistributedNotificationCenter.default().removeObserver(
            self,
            name: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )

        if let hot_key_ref = self.toggle_keyboard_lock_hot_key_ref {
            UnregisterEventHotKey(hot_key_ref)
        }
        self.toggle_keyboard_lock_hot_key_ref = nil
        self.toggle_keyboard_lock_key_code = nil

        if let event_handler_ref = self.toggle_keyboard_lock_hot_key_event_handler_ref {
            RemoveEventHandler(event_handler_ref)
            self.toggle_keyboard_lock_hot_key_event_handler_ref = nil
        }
    }

    // RegisterEventHotKey needs a physical key code, so resolve logical "l" from the input source.
    private func current_keyboard_lock_key_code() -> CGKeyCode? {
        guard let unmanaged_input_source = TISCopyCurrentKeyboardInputSource() else {
            return nil
        }
        let input_source = unmanaged_input_source.takeRetainedValue()
        defer { withExtendedLifetime(input_source) {} }
        guard let input_source_id_pointer = TISGetInputSourceProperty(
            input_source,
            kTISPropertyInputSourceID
        ) else {
            return nil
        }
        let input_source_id = Unmanaged<CFString>
            .fromOpaque(input_source_id_pointer)
            .takeUnretainedValue() as String

        switch input_source_id {
            case "com.apple.keylayout.ABC":
                return CGKeyCode(kVK_ANSI_L)
            case "com.apple.keylayout.Dvorak":
                return CGKeyCode(kVK_ANSI_P)
            default:
                return nil
        }
    }

    @objc
    private func keyboard_input_source_changed(_ notification: Notification) {
        DispatchQueue.main.async {
            self.register_keyboard_lock_hot_key()
        }
    }

    func toggle_input_mode() {
        guard !self.keyboard_locked else {
            return
        }
        // Change mode.
        self.input_mode = self.input_mode == .telex ? .literal : .telex
        self.update_status_item()
        // Reset state.
        self.engine.reset()
        // Play sound when toggling mode.
        self.toggle_sound.stop()
        self.toggle_sound = self.input_mode == .telex ? self.telex_sound : self.literal_sound
        self.toggle_sound.play()
    }

    func toggle_keyboard_lock() {
        guard self.keyboard_locked || self.event_tap != nil else {
            return
        }
        self.keyboard_locked.toggle()
        self.engine.reset()
        self.update_status_item()
        // Play sound when toggling keyboard lock.
        self.toggle_sound.stop()
        if self.keyboard_locked {
            self.toggle_sound = self.keyboard_locked_sound
        } else {
            self.toggle_sound = self.input_mode == .telex
                ? self.telex_sound
                : self.literal_sound
        }
        self.toggle_sound.play()
    }

    private func update_status_item() {
        self.lock_keyboard_item?.state = self.keyboard_locked ? .on : .off

        guard let button = self.status_item?.button else {
            return
        }
        if self.keyboard_locked {
            button.image = self.keyboard_locked_image
            button.toolTip = "Lex - Keyboard locked"
            button.setAccessibilityLabel("Lex - Keyboard locked")
        } else if self.input_mode == .telex {
            button.image = self.telex_image
            button.toolTip = "Lex - Telex input"
            button.setAccessibilityLabel("Lex - Telex input")
        } else {
            button.image = self.literal_image
            button.toolTip = "Lex - Literal input"
            button.setAccessibilityLabel("Lex - Literal input")
        }
    }

    private func start_event_tap() {
        precondition(self.event_tap == nil)
        precondition(self.event_tap_run_loop_source == nil)

        let options = [ kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true ] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            print("Accessibility permission required. Grant access in System Settings > Privacy & Security > Accessibility, then relaunch.")
            return
        }
        guard AXUIElementSetMessagingTimeout(
            system_wide_accessibility_element,
            0.1
        ) == .success else {
            print("Failed to set the Accessibility messaging timeout.")
            return
        }

        // TODO: we must understand the mask.
        let event_mask =
            (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
            | (CGEventMask(1) << CGEventType.leftMouseDown.rawValue)
            | (CGEventMask(1) << CGEventType.rightMouseDown.rawValue)
            | (CGEventMask(1) << CGEventType.tapDisabledByTimeout.rawValue)
            | (CGEventMask(1) << CGEventType.tapDisabledByUserInput.rawValue)
        let self_pointer = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(event_mask),
            callback: event_tap_callback,
            userInfo: self_pointer
        ) else {
            print("Failed to create event tap.")
            return
        }
        let run_loop_source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.event_tap = tap
        self.event_tap_run_loop_source = run_loop_source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), run_loop_source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.lock_keyboard_item?.isEnabled = true
        print("Event tap started.")
    }

    private func stop_event_tap() {
        guard let tap = self.event_tap else {
            return
        }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let run_loop_source = self.event_tap_run_loop_source {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), run_loop_source, .commonModes)
        }
        CFMachPortInvalidate(tap)
        self.event_tap_run_loop_source = nil
        self.event_tap = nil
        print("Event tap stopped.")
    }

    private func initialize_synthetic_event_source() {
        precondition(self.synthetic_event_source == nil)
        let source = CGEventSource(stateID: .privateState)
        source?.userData = synthetic_event_source_user_data
        self.synthetic_event_source = source
    }

    private func destroy_synthetic_event_source() {
        self.synthetic_event_source = nil
    }

    private func initialize_status_item() {
        precondition(self.status_item == nil)

        let status_item = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )
        self.status_item = status_item

        let menu = NSMenu()
        menu.autoenablesItems = false

        let lock_item = NSMenuItem(
            title: "Lock Keyboard",
            action: #selector(lock_keyboard(_:)),
            keyEquivalent: "l"
        )
        lock_item.target = self
        lock_item.keyEquivalentModifierMask = [.control, .option, .command]
        lock_item.isEnabled = false
        self.lock_keyboard_item = lock_item
        menu.addItem(lock_item)

        menu.addItem(.separator())

        let quit_item = NSMenuItem(
            title: "Quit",
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quit_item.target = self
        menu.addItem(quit_item)

        status_item.menu = menu
        self.update_status_item()
    }

    private func destroy_status_item() {
        guard let status_item = self.status_item else {
            return
        }

        NSStatusBar.system.removeStatusItem(status_item)
        self.lock_keyboard_item = nil
        self.status_item = nil
    }

    private func register_login_item() {
        if SMAppService.mainApp.status == .enabled {
            // Login item enabled, store the check to not attempt again.
            UserDefaults.standard.set(true, forKey: login_item_registration_attempted_key)
            return
        }

        let login_item_registration_attempted = UserDefaults.standard.bool(
            forKey: login_item_registration_attempted_key
        )

        if login_item_registration_attempted {
            // Don't try to enable login item again when already attempted.
            return
        }

        do {
            try SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: login_item_registration_attempted_key)
        } catch {
            print("Failed to register login item: \(error)")
        }
    }

    @objc
    private func lock_keyboard(_ sender: Any?) {
        self.toggle_keyboard_lock()
    }

    @objc
    private func quit(_ sender: Any?) {
       NSApp.terminate(nil) 
    }

    func get_synthetic_event_source() -> CGEventSource? {
        return self.synthetic_event_source
    }

    func enable_event_tap() {
        // Re-enable event tap if it was disabled by timeout (when the call back run too slow) or
        // disabled by senisitve input field.
        guard let event_tap = self.event_tap else {
            return
        }
        CGEvent.tapEnable(tap: event_tap, enable: true)
    }

    func is_literal() -> Bool {
        return self.input_mode == .literal
    }

    func is_keyboard_locked() -> Bool {
        return self.keyboard_locked
    }

    func registered_keyboard_lock_key_code() -> CGKeyCode? {
        guard self.toggle_keyboard_lock_hot_key_ref != nil,
              let key_code = self.toggle_keyboard_lock_key_code else {
            return nil
        }
        return key_code
    }
}

private func handle_input_mode_hot_key(
    _ next_handler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ user_data: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let user_data else {
        return OSStatus(eventNotHandledErr)
    }
    var hot_key_id = EventHotKeyID()
    let parameter_status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hot_key_id
    )
    guard parameter_status == noErr,
          hot_key_id.signature == toggle_input_mode_hot_key_id.signature,
          hot_key_id.id == toggle_input_mode_hot_key_id.id else {
        return OSStatus(eventNotHandledErr)
    }

    let app_delegate = Unmanaged<AppDelegate>
        .fromOpaque(user_data)
        .takeUnretainedValue()
    DispatchQueue.main.async {
        app_delegate.toggle_input_mode()
    }
    return noErr
}

private func handle_keyboard_lock_hot_key(
    _ next_handler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ user_data: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let user_data else {
        return OSStatus(eventNotHandledErr)
    }
    var hot_key_id = EventHotKeyID()
    let parameter_status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hot_key_id
    )
    guard parameter_status == noErr,
          hot_key_id.signature == toggle_keyboard_lock_hot_key_id.signature,
          hot_key_id.id == toggle_keyboard_lock_hot_key_id.id else {
        return OSStatus(eventNotHandledErr)
    }

    let app_delegate = Unmanaged<AppDelegate>
        .fromOpaque(user_data)
        .takeUnretainedValue()
    DispatchQueue.main.async {
        app_delegate.toggle_keyboard_lock()
    }
    return noErr
}

private func matches_keyboard_lock_hot_key(
    key_code: CGKeyCode,
    event_key_code: Int64,
    event_flags: CGEventFlags
) -> Bool {
    let shortcut_modifier_mask: CGEventFlags = [
        .maskCommand,
        .maskAlternate,
        .maskControl,
        .maskShift,
    ]
    let keyboard_lock_modifiers: CGEventFlags = [
        .maskCommand,
        .maskAlternate,
        .maskControl,
    ]
    return event_key_code == Int64(key_code) &&
        event_flags.intersection(shortcut_modifier_mask) == keyboard_lock_modifiers
}

private func select_previous_characters(
    _ character_count: Int,
    in accessibility_application: AXUIElement
) -> Bool {
    precondition(character_count > 0)

    var focused_element_value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(
        accessibility_application,
        kAXFocusedUIElementAttribute as CFString,
        &focused_element_value
    ) == .success, let focused_element_value,
            CFGetTypeID(focused_element_value) == AXUIElementGetTypeID() else {
        return false
    }
    let focused_element = focused_element_value as! AXUIElement

    var selected_range_value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(
        focused_element,
        kAXSelectedTextRangeAttribute as CFString,
        &selected_range_value
    ) == .success, let selected_range_value,
            CFGetTypeID(selected_range_value) == AXValueGetTypeID() else {
        return false
    }
    let selected_range_ax_value = selected_range_value as! AXValue
    guard AXValueGetType(selected_range_ax_value) == .cfRange else {
        return false
    }

    var selected_range = CFRange()
    guard AXValueGetValue(selected_range_ax_value, .cfRange, &selected_range),
            selected_range.length == 0,
            selected_range.location >= character_count else {
        return false
    }

    var replacement_range = CFRange(
        location: selected_range.location - character_count,
        length: character_count
    )
    guard let replacement_range_value = AXValueCreate(.cfRange, &replacement_range) else {
        return false
    }
    return AXUIElementSetAttributeValue(
        focused_element,
        kAXSelectedTextRangeAttribute as CFString,
        replacement_range_value
    ) == .success
}

private func event_tap_callback(
    proxy: CGEventTapProxy,
    type event_type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // passthrough event when the event tap is inactive.
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let app_delegate = Unmanaged<AppDelegate>
            .fromOpaque(userInfo)
            .takeUnretainedValue()

    switch event_type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // Reset engine.
            app_delegate.engine.reset()
            // Re-enable tap.
            app_delegate.enable_event_tap()
            // Pass through event.
            return Unmanaged.passUnretained(event)

        case .leftMouseDown, .rightMouseDown:
            // Reset engine.
            app_delegate.engine.reset()
            // Pass through event.
            return Unmanaged.passUnretained(event)

        case .flagsChanged:
            // Pass through event.
            // Don't reset for plain Shift / Caps Lock.
            return Unmanaged.passUnretained(event)

        case .keyDown:
            // Handle key down.

            // Let the registered hot key handler lock or unlock the keyboard.
            if let key_code = app_delegate.registered_keyboard_lock_key_code(),
                    matches_keyboard_lock_hot_key(
                        key_code: key_code,
                        event_key_code: event.getIntegerValueField(.keyboardEventKeycode),
                        event_flags: event.flags
                    ) {
                return Unmanaged.passUnretained(event)
            }

            if app_delegate.is_keyboard_locked() {
                return nil
            }

            // passthrough event when in literal mode.
            if app_delegate.is_literal() {
                return Unmanaged.passUnretained(event)
            }

            // Ignore Lex's synthetic events.
            if event.getIntegerValueField(.eventSourceUserData) == synthetic_event_source_user_data {
                return Unmanaged.passUnretained(event)
            }

            // Ignore hot key combination when holding either: Command, Option, Control.
            let modifier_mask: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate]
            if !event.flags.intersection(modifier_mask).isEmpty {
                // Reset the engine because user execute other action while typing.
                app_delegate.engine.reset()
                // Passthrough the action.
                return Unmanaged.passUnretained(event)
            }

            // Get keycode to detect special key pressed.
            let key_code = event.getIntegerValueField(.keyboardEventKeycode)
            switch key_code {
                case Int64(kVK_Space):
                    // Reset the state to process new word.
                    app_delegate.engine.reset()
                    // Passthrough the space.
                    return Unmanaged.passUnretained(event)

                case Int64(kVK_Delete):
                    // User input backspace.
                    // Call backspace action to keep buffer in sync with real input.
                    app_delegate.engine.backspace()
                    // Passthrough backspace.
                    return Unmanaged.passUnretained(event)

                default:
                        // Reset state for unhandled keycode.
                        // app_delegate.engine.reset()
                        // return Unmanaged.passUnretained(event)
                        break
            }

            // Detect and handle alphabetic input.
            var character_count = 0
                event.keyboardGetUnicodeString(
                        maxStringLength: 0,
                        actualStringLength: &character_count,
                        unicodeString: nil
                        )
                guard character_count == 1 else {
                    // No character, could be a special key, could not handle this case.
                    app_delegate.engine.reset()
                        return Unmanaged.passUnretained(event)
                }

            // Get Unicode character.
            var character: UniChar = 0
                event.keyboardGetUnicodeString(
                        maxStringLength: 1,
                        actualStringLength: &character_count,
                        unicodeString: &character
                        )
                // Check if it's alphabetic.
                let is_alphabetic = (character >= 65 && character <= 90)
                || (character >= 97 && character <= 122)
                guard is_alphabetic else {
                    // No alphabitec, reset state.
                    app_delegate.engine.reset()
                        return Unmanaged.passUnretained(event)
                }
                guard let input = UnicodeScalar(UInt32(character)) else {
                    app_delegate.engine.reset()
                    return Unmanaged.passUnretained(event)
                }

            // Valid input, safe to process with the engine.
            if app_delegate.engine.buffer_full() {
                // The state reach the limit, reset it before continue processing.
                app_delegate.engine.reset()
            }

            if app_delegate.engine.buffer_effective_full() {
                // The buffer effective is full, process literal input.
                app_delegate.engine.add(input)
                return Unmanaged.passUnretained(event)
            } else {
                // The buffer effective has room, process with synthetic backspace and replacement.

                // Send the input character to engine.
                app_delegate.engine.add(input)

                // Calculate synthetic backspaces.
                let backspace_count = app_delegate.engine.synthetic_backspaces()

                // Anchor Safari detection and Accessibility lookup to this event's target process.
                let target_process_identifier_value = event.getIntegerValueField(
                    .eventTargetUnixProcessID
                )
                if let target_process_identifier = pid_t(exactly: target_process_identifier_value),
                        target_process_identifier > 0,
                        let target_application = NSRunningApplication(
                            processIdentifier: target_process_identifier
                        ),
                        target_application.bundleIdentifier == "com.apple.Safari" {
                    // Safari can process separate keyboard editing commands out of order. Select
                    // the old text synchronously, then replace it with the returned key event.
                    if backspace_count > 0 {
                        let accessibility_application = AXUIElementCreateApplication(
                            target_process_identifier
                        )
                        if !select_previous_characters(
                            backspace_count,
                            in: accessibility_application
                        ) {
                            app_delegate.engine.reset()
                            return Unmanaged.passUnretained(event)
                        }
                    }
                    app_delegate.engine.compose_replacement { replacement in
                        guard let replacement_base_address = replacement.baseAddress else {
                            return
                        }
                        event.keyboardSetUnicodeString(
                            stringLength: replacement.count,
                            unicodeString: replacement_base_address
                        )
                    }
                    return Unmanaged.passUnretained(event)
                }

                guard let synthetic_event_source = app_delegate.get_synthetic_event_source() else {
                    // No event source to send synthetic event.
                    app_delegate.engine.reset()
                    return Unmanaged.passUnretained(event)
                }

                // Post synthetic backspaces to event tap.
                if backspace_count > 0 {
                    for _ in 0..<backspace_count {
                        if let synthetic_backspace_down = CGEvent(
                            keyboardEventSource: synthetic_event_source,
                            virtualKey: CGKeyCode(kVK_Delete),
                            keyDown: true
                        ) {
                            synthetic_backspace_down.tapPostEvent(proxy)
                        }
                        
                        if let synthetic_backspace_up = CGEvent(
                            keyboardEventSource: synthetic_event_source,
                            virtualKey: CGKeyCode(kVK_Delete),
                            keyDown: false
                        ) {
                            synthetic_backspace_up.tapPostEvent(proxy)
                        }
                    }
                }
                
                // Compose replacement.
                app_delegate.engine.compose_replacement { replacement in
                    guard let replacement_base_address = replacement.baseAddress else {
                        return
                    }

                    if let synthetic_characters_down = CGEvent(
                        keyboardEventSource: synthetic_event_source,
                        virtualKey: 0,
                        keyDown: true
                    ) {
                        synthetic_characters_down.keyboardSetUnicodeString(
                            stringLength: replacement.count,
                            unicodeString: replacement_base_address
                        )
                        synthetic_characters_down.tapPostEvent(proxy)
                    }

                    if let synthetic_characters_up = CGEvent(
                        keyboardEventSource: synthetic_event_source,
                        virtualKey: 0,
                        keyDown: false
                    ) {
                        synthetic_characters_up.keyboardSetUnicodeString(
                            stringLength: replacement.count,
                            unicodeString: replacement_base_address
                        )
                        synthetic_characters_up.tapPostEvent(proxy)
                    }
                }
                return nil
            }


        default:
            return Unmanaged.passUnretained(event)
    }
}

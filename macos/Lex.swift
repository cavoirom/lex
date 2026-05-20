import Carbon
import OSLog
import SwiftUI

@main
struct LexApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var app_delegate

    var body: some Scene {
        MenuBarExtra {
            LexMenu(
                app_delegate: app_delegate,
                app_state: app_delegate.app_state
            )
        } label: {
            LexMenuBarLabel(app_state: app_delegate.app_state)
        }
        .menuBarExtraStyle(.menu)
    }
}

struct LexMenuBarLabel: View {
    @ObservedObject var app_state: AppState

    var body: some View {
        Label("Lex", systemImage: app_state.mode == .telex ? "pencil" : "pencil.slash")
        .labelStyle(.iconOnly)
        .accessibilityLabel("Lex")
    }
}

// Namespace: LEX!
private let toggle_input_mode_hot_key_id = EventHotKeyID(signature: OSType(0x4C455821), id: 1)
// Tag: LEX!
private let synthetic_event_source_user_data: Int64 = 0x4C455821

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor
    let app_state = AppState()

    private var engine_state: UnsafeMutableRawPointer?
    private var signal_sources: [DispatchSourceSignal] = []
    private var toggle_input_mode_hot_key_ref: EventHotKeyRef?
    private var toggle_input_mode_sound: NSSound?

    private var event_tap: CFMachPort?
    private var event_tap_run_loop_source: CFRunLoopSource?
    private var synthetic_event_source: CGEventSource?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Activated.")
        install_signal_handler(SIGINT)
        install_signal_handler(SIGTERM)
        initialize_engine_state()
        initialize_synthetic_event_source()
        start_event_tap()
        register_toggle_input_mode_hot_key()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("Shutting down...")
        unregister_toggle_input_mode_hot_key()
        stop_event_tap()
        destroy_synthetic_event_source()
        destroy_engine_state()
        signal_sources.removeAll()
    }

    private func initialize_engine_state() {
        precondition(engine_state == nil)
        let byte_count = Int(lex_state_size)
        let alignment = Int(lex_state_alignment)
        let state = UnsafeMutableRawPointer.allocate(
            byteCount: byte_count,
            alignment: alignment
        )
        lex_init(state)
        engine_state = state
    }

    private func destroy_engine_state() {
        guard let state = engine_state else {
            return
        }
        state.deallocate()
        engine_state = nil
    }

    private func install_signal_handler(_ signal_number: Int32) {
        signal(signal_number, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: signal_number, queue: .main)
        source.setEventHandler {
            NSApp.terminate(nil)
        }
        source.resume()
        signal_sources.append(source)
    }

    private func register_toggle_input_mode_hot_key() {
        let self_pointer = Unmanaged.passUnretained(self).toOpaque()
        var event_type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData else {
                    return OSStatus(eventNotHandledErr)
                }
                var hot_key_id = EventHotKeyID()
                GetEventParameter(
                    event!,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hot_key_id
                )
                if hot_key_id.signature == toggle_input_mode_hot_key_id.signature &&
                        hot_key_id.id == toggle_input_mode_hot_key_id.id {
                    let app_delegate = Unmanaged<AppDelegate>
                        .fromOpaque(userData)
                        .takeUnretainedValue()
                    Task { @MainActor in
                            app_delegate.toggle_input_mode()
                    }
                }
                return noErr
            },
            1,
            &event_type,
            self_pointer,
            nil
        )
        let id = toggle_input_mode_hot_key_id
        RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(controlKey | optionKey),
            id,
            GetApplicationEventTarget(),
            0,
            &toggle_input_mode_hot_key_ref
        )
    }

    private func unregister_toggle_input_mode_hot_key() {
        guard let toggle_input_mode_hot_key_ref else {
            return
        }
        UnregisterEventHotKey(toggle_input_mode_hot_key_ref)
        self.toggle_input_mode_hot_key_ref = nil
    }

    @MainActor
    private func toggle_input_mode() {
        app_state.mode = app_state.mode == .telex ? .literal : .telex
        // TODO: this flow must change when finish integrating with engine.
        toggle_input_mode_sound?.stop()
        let sound_name: NSSound.Name = app_state.mode == .telex ? "Pop" : "Tink"
        toggle_input_mode_sound = NSSound(named: sound_name)
        toggle_input_mode_sound?.play()
    }

    private func start_event_tap() {
        precondition(event_tap == nil)
        precondition(event_tap_run_loop_source == nil)

        let options = [ kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true ] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            print("Accessibility permission required. Grant access in System Settings > Privacy & Security > Accessibility, then relaunch.")
            return
        }

        // TODO: we must understand the mask.
        // let event_mask = (1 << CGEventType.keyDown.rawValue
        //         | 1 << CGEventType.tapDisabledByTimeout.rawValue
        //         | 1 << CGEventType.tapDisabledByUserInput.rawValue)
        let event_mask =
            (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
            | (CGEventMask(1) << CGEventType.leftMouseDown.rawValue)
            | (CGEventMask(1) << CGEventType.rightMouseDown.rawValue)
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
        event_tap = tap
        event_tap_run_loop_source = run_loop_source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), run_loop_source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("Event tap started.")
    }

    private func stop_event_tap() {
        guard let tap = event_tap else {
            return
        }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let run_loop_source = event_tap_run_loop_source {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), run_loop_source, .commonModes)
        }
        CFMachPortInvalidate(tap)
        event_tap_run_loop_source = nil
        event_tap = nil
        print("Event tap stopped.")
    }

    private func initialize_synthetic_event_source() {
        precondition(synthetic_event_source == nil)
        let source = CGEventSource(stateID: .privateState)
        source?.userData = synthetic_event_source_user_data
        synthetic_event_source = source
    }

    private func destroy_synthetic_event_source() {
        synthetic_event_source = nil
    }

    func enable_event_tap() {
        // TODO: why do we need to re-enable the tap?
        guard let event_tap else {
            return
        }
        CGEvent.tapEnable(tap: event_tap, enable: true)
    }
}

private func event_tap_callback(
    proxy: CGEventTapProxy,
    type event_type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let app_delegate = Unmanaged<AppDelegate>
            .fromOpaque(userInfo)
            .takeUnretainedValue()
    if event_type == .tapDisabledByTimeout || event_type == .tapDisabledByUserInput {
        app_delegate.enable_event_tap()
        return Unmanaged.passUnretained(event)
    }
    guard event_type == .keyDown else {
        return Unmanaged.passUnretained(event)
    }
    if event.getIntegerValueField(.eventSourceUserData) == synthetic_event_source_user_data {
        return Unmanaged.passUnretained(event)
    }
    var character_count = 0
    event.keyboardGetUnicodeString(
        maxStringLength: 0,
        actualStringLength: &character_count,
        unicodeString: nil
    )
    if character_count > 0 {
        var characters = [UniChar](repeating: 0, count: character_count)
        event.keyboardGetUnicodeString(
            maxStringLength: character_count,
            actualStringLength: &character_count,
            unicodeString: &characters
        )
        let s = String(
            utf16CodeUnits: characters,
            count: character_count
        )
        print("Input character: \(s)")
    } else {
        let key_code = event.getIntegerValueField(.keyboardEventKeycode)
        print("Input key code: \(key_code)")
    }
    NSSound(named: "Tink")?.play()
    return Unmanaged.passUnretained(event)
}

enum InputMode {
    case literal, telex
}

@MainActor
final class AppState: ObservableObject {
    @Published var mode: InputMode = .telex
}

struct LexMenu: View {
    let app_delegate: AppDelegate
    @ObservedObject var app_state: AppState

    var body: some View {
        Button("Lock inputs") {}
        Divider()
        Button("Quit") {
            NSApp.terminate(nil)
        }
    }
}

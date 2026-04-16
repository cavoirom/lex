import Cocoa
import Carbon

private let syntheticTag: Int64 = 0x4C4558
private let composeBufLen: Int = 32
private let toggleHotKeyID = EventHotKeyID(signature: OSType(0x4C455821), id: 1) // "LEX!"

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var eventTap: CFMachPort?
    var syntheticSource: CGEventSource?
    var vietnameseEnabled: Bool = true
    var hotKeyRef: EventHotKeyRef?

    // Engine state (allocated by Swift, owned by Zig)
    var engineState: UnsafeMutableRawPointer!

    // Diff snapshots: what we believe is currently on screen vs what Zig just produced
    var currentRendered: [UniChar] = []
    var composeBuf: UnsafeMutableBufferPointer<UInt16>!

    func applicationDidFinishLaunching(_ notification: Notification) {
        syntheticSource = CGEventSource(stateID: .privateState)
        syntheticSource?.userData = syntheticTag

        // Allocate engine state
        let size = state_size()
        engineState = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 8)
        init_state(engineState)

        // Allocate composition buffer
        let rawBuf = UnsafeMutablePointer<UInt16>.allocate(capacity: composeBufLen)
        composeBuf = UnsafeMutableBufferPointer(start: rawBuf, count: composeBufLen)

        setupMenuBar()
        registerHotKey()
        requestAccessAndStartTap()
        observeAppSwitch()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "Ꝟ"
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Exit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func requestAccessAndStartTap() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            print("Accessibility permission required. Please grant access in System Settings > Privacy & Security > Accessibility, then relaunch.")
            return
        }
        startEventTap()
    }

    private func observeAppSwitch() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resetEngine()
        }
    }

    func resetEngine() {
        reset(engineState)
        currentRendered = []
    }

    private func startEventTap() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.tapDisabledByTimeout.rawValue)
            | (1 << CGEventType.tapDisabledByUserInput.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: selfPtr
        ) else {
            print("Failed to create event tap. Ensure Input Monitoring permission is granted.")
            return
        }

        eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("Event tap started.")
    }

    private func registerHotKey() {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event!, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            if hotKeyID.id == toggleHotKeyID.id {
                let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                appDelegate.toggleVietnamese()
            }
            return noErr
        }, 1, &eventType, selfPtr, nil)

        // Ctrl+Opt+Space: keyCode 49 (kVK_Space), controlKey | optionKey
        let id = toggleHotKeyID
        RegisterEventHotKey(UInt32(kVK_Space),
                            UInt32(controlKey | optionKey),
                            id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func toggleVietnamese() {
        vietnameseEnabled = !vietnameseEnabled
        self.resetEngine()
        if let button = statusItem.button {
            button.title = vietnameseEnabled ? "Ꝟ" : "𝙰"
        }
        NSSound(named: NSSound.Name(vietnameseEnabled ? "Tink" : "Pop"))?.play()
    }

    /// Read composed UTF-16 from the engine into composeBuf, returns the array or nil on overflow
    func readComposed() -> [UniChar]? {
        let count = get_composed_utf16(engineState, composeBuf.baseAddress!, UInt16(composeBufLen))
        if count == 0xFF {
            // Buffer overflow — fail safe
            resetEngine()
            return nil
        }
        return Array(composeBuf.prefix(Int(count)))
    }

    /// Compute and emit the minimal diff between currentRendered and nextRendered
    func applyDiff(next: [UniChar]) {
        guard let source = syntheticSource else { return }

        // Find longest common prefix
        let minLen = min(currentRendered.count, next.count)
        var diverge = 0
        while diverge < minLen && currentRendered[diverge] == next[diverge] {
            diverge += 1
        }

        let numBackspaces = currentRendered.count - diverge
        let replacementChars = Array(next.suffix(from: diverge))

        // Emit backspaces
        for _ in 0..<numBackspaces {
            if let down = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: true),
               let up = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: false) {
                down.post(tap: .cgSessionEventTap)
                up.post(tap: .cgSessionEventTap)
            }
        }

        // Emit replacement characters in a single multi-char CGEvent
        if !replacementChars.isEmpty {
            var chars = replacementChars
            if let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
               let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                down.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
                up.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
                down.post(tap: .cgSessionEventTap)
                up.post(tap: .cgSessionEventTap)
            }
        }

        currentRendered = next
    }
}

func eventTapCallback(
    proxy: CGEventTapProxy,
    type eventType: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()

    // Re-enable tap if disabled
    if eventType == .tapDisabledByTimeout || eventType == .tapDisabledByUserInput {
        if let tap = appDelegate.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        appDelegate.resetEngine()
        return Unmanaged.passUnretained(event)
    }

    // Mouse click → reset (caret moved)
    if eventType == .leftMouseDown || eventType == .rightMouseDown {
        appDelegate.resetEngine()
        return Unmanaged.passUnretained(event)
    }

    // Modifier flags changed
    if eventType == .flagsChanged {
        return Unmanaged.passUnretained(event)
    }

    guard eventType == .keyDown else {
        return Unmanaged.passUnretained(event)
    }

    // Ignore our own synthetic events
    if event.getIntegerValueField(.eventSourceUserData) == syntheticTag {
        return Unmanaged.passUnretained(event)
    }

    // Modifier keys held → reset and passthrough
    let flags = event.flags
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let modifierMask: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate]
    if !flags.intersection(modifierMask).isEmpty {
        appDelegate.resetEngine()
        return Unmanaged.passUnretained(event)
    }

    // Vietnamese input disabled → passthrough
    if !appDelegate.vietnameseEnabled {
        return Unmanaged.passUnretained(event)
    }

    // Navigation / editing keys → reset and passthrough
    switch keyCode {
    case 0x24, 0x4C: // Return, Enter
        appDelegate.resetEngine()
        return Unmanaged.passUnretained(event)
    case 0x30: // Tab
        appDelegate.resetEngine()
        return Unmanaged.passUnretained(event)
    case 0x35: // Escape
        appDelegate.resetEngine()
        return Unmanaged.passUnretained(event)
    case 0x7B, 0x7C, 0x7D, 0x7E: // Arrow keys
        appDelegate.resetEngine()
        return Unmanaged.passUnretained(event)
    case 0x73, 0x77, 0x74, 0x79: // Home, End, PageUp, PageDown
        appDelegate.resetEngine()
        return Unmanaged.passUnretained(event)
    case 0x75: // Forward delete
        appDelegate.resetEngine()
        return Unmanaged.passUnretained(event)
    default:
        break
    }

    // Backspace
    if keyCode == 0x33 {
        let disposition = backspace(appDelegate.engineState)
        if disposition == 1 {
            // Read new composed state and diff
            if let next = appDelegate.readComposed() {
                if next.isEmpty {
                    // All spans removed — just let the native backspace through
                    appDelegate.currentRendered = []
                    return Unmanaged.passUnretained(event)
                }
                appDelegate.applyDiff(next: next)
                return nil // swallow the original backspace
            }
        }
        return Unmanaged.passUnretained(event)
    }

    // Get the Unicode character from the event
    var charCount: Int = 0
    event.keyboardGetUnicodeString(maxStringLength: 0, actualStringLength: &charCount, unicodeString: nil)

    guard charCount == 1 else {
        appDelegate.resetEngine()
        return Unmanaged.passUnretained(event)
    }

    var unicodeChar: UniChar = 0
    event.keyboardGetUnicodeString(maxStringLength: 1, actualStringLength: &charCount, unicodeString: &unicodeChar)

    // Feed to engine
    let disposition = add(appDelegate.engineState, unicodeChar)

    if disposition == 0 {
        // Passthrough — engine reset or non-alphanumeric
        appDelegate.currentRendered = []
        return Unmanaged.passUnretained(event)
    }

    // Consumed — read composed output and diff
    if let next = appDelegate.readComposed() {
        appDelegate.applyDiff(next: next)
        return nil // swallow original keystroke
    }

    // Fallback: if readComposed failed, just pass through
    return Unmanaged.passUnretained(event)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate
app.run()

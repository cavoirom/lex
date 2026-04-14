import Cocoa

private let syntheticTag: Int64 = 0x4C4558

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var eventTap: CFMachPort?
    var syntheticSource: CGEventSource?

    func applicationDidFinishLaunching(_ notification: Notification) {
        syntheticSource = CGEventSource(stateID: .privateState)
        syntheticSource?.userData = syntheticTag
        setupMenuBar()
        requestAccessAndStartTap()
        observeAppSwitch()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "⌨"
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
        ) { _ in
            reset_state()
        }
    }

    private func startEventTap() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
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

    func emitSyntheticEvents(result: ProcessKeyEventResult) {
        guard let source = syntheticSource else { return }

        for _ in 0..<result.num_backspaces {
            if let down = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: true),
               let up = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: false) {
                down.post(tap: .cgSessionEventTap)
                up.post(tap: .cgSessionEventTap)
            }
        }

        for i in 0..<Int(result.num_chars) {
            var char = result.chars[i]
            if let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
               let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &char)
                up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &char)
                down.post(tap: .cgSessionEventTap)
                up.post(tap: .cgSessionEventTap)
            }
        }
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

    if eventType == .tapDisabledByTimeout || eventType == .tapDisabledByUserInput {
        if let tap = appDelegate.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        reset_state()
        return Unmanaged.passUnretained(event)
    }

    if eventType == .flagsChanged {
        return Unmanaged.passUnretained(event)
    }

    guard eventType == .keyDown else {
        return Unmanaged.passUnretained(event)
    }

    if event.getIntegerValueField(.eventSourceUserData) == syntheticTag {
        return Unmanaged.passUnretained(event)
    }

    let flags = event.flags
    let modifierMask: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate]
    if !flags.intersection(modifierMask).isEmpty {
        reset_state()
        return Unmanaged.passUnretained(event)
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    if keyCode == 0x33 {
        let _ = process_backspace()
        return Unmanaged.passUnretained(event)
    }

    var charCount: Int = 0
    event.keyboardGetUnicodeString(maxStringLength: 0, actualStringLength: &charCount, unicodeString: nil)

    guard charCount == 1 else {
        reset_state()
        return Unmanaged.passUnretained(event)
    }

    var unicodeChar: UniChar = 0
    event.keyboardGetUnicodeString(maxStringLength: 1, actualStringLength: &charCount, unicodeString: &unicodeChar)

    let result = process_key_event(unicodeChar)

    if result.swallow_event {
        appDelegate.emitSyntheticEvents(result: result)
        return nil
    }

    return Unmanaged.passUnretained(event)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate
app.run()

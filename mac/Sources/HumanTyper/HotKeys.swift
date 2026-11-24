import AppKit
import Carbon.HIToolbox

/// System-wide hotkeys via Carbon RegisterEventHotKey (works without any extra permission).
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var refs: [EventHotKeyRef] = []
    private var handlers: [UInt32: () -> Void] = [:]
    private var installed = false

    func register(_ keys: [(HotKey, () -> Void)]) {
        unregisterAll()
        installHandler()
        for (i, (key, handler)) in keys.enumerated() where !key.isNone {
            let id = UInt32(i + 1)
            var ref: EventHotKeyRef?
            let hkID = EventHotKeyID(signature: OSType(0x4854_5950), id: id)
            if RegisterEventHotKey(key.keyCode, key.modifiers, hkID, GetApplicationEventTarget(), 0, &ref) == noErr, let ref {
                refs.append(ref)
                handlers[id] = handler
            }
        }
    }

    func unregisterAll() {
        for r in refs { UnregisterEventHotKey(r) }
        refs.removeAll()
        handlers.removeAll()
    }

    fileprivate func fire(_ id: UInt32) {
        guard let h = handlers[id] else { return }
        DispatchQueue.main.async { h() }
    }

    private func installHandler() {
        if installed { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hk = EventHotKeyID()
            let st = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                       nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            if st == noErr { HotKeyCenter.shared.fire(hk.id) }
            return noErr
        }, 1, &spec, nil, nil)
    }

    /// NSEvent modifier flags → Carbon modifier mask.
    static func carbonModifiers(_ f: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if f.contains(.command) { m |= UInt32(cmdKey) }
        if f.contains(.option) { m |= UInt32(optionKey) }
        if f.contains(.control) { m |= UInt32(controlKey) }
        if f.contains(.shift) { m |= UInt32(shiftKey) }
        return m
    }
}

/// Watches the user's own keyboard / mouse input in other apps while typing, so the engine can pause
/// when the user takes over. Our own synthetic keystrokes carry KeyboardOut.marker and are ignored.
final class InputMonitor {
    private var monitor: Any?

    func start(_ onUserInput: @escaping () -> Void) {
        stop()
        let ownPid = Int64(ProcessInfo.processInfo.processIdentifier)
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]) { e in
            if let cg = e.cgEvent {
                if cg.getIntegerValueField(.eventSourceUserData) == KeyboardOut.marker { return }
                if cg.getIntegerValueField(.eventSourceUnixProcessID) == ownPid { return }
            }
            onUserInput()
        }
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
    }
}

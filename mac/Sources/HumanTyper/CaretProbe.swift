import AppKit
import ApplicationServices

/// The focused text element and the caret position inside it (UTF-16 offset), read via the Accessibility API.
struct CaretSnapshot {
    var focus: AXUIElement?
    var loc: Int = -1

    var caretOk: Bool { loc >= 0 }

    func sameFocus(_ o: CaretSnapshot) -> Bool {
        guard let a = focus, let b = o.focus else { return false }
        return CFEqual(a, b)
    }

    func near(_ o: CaretSnapshot) -> Bool { caretOk && o.caretOk && loc == o.loc && sameFocus(o) }
}

enum CaretProbe {
    private static let system: AXUIElement = {
        let s = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(s, 0.3)
        return s
    }()

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that sends the user to Privacy & Security → Accessibility.
    static func requestTrust() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func frontPid() -> pid_t {
        NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
    }

    static func appName(_ pid: pid_t) -> String {
        if pid == ProcessInfo.processInfo.processIdentifier { return "HumanTyper 本身" }
        return NSRunningApplication(processIdentifier: pid)?.localizedName ?? "未知程序"
    }

    /// Chrome / Electron only build their accessibility tree when asked to.
    static func enableAccessibility(for pid: pid_t) {
        guard pid > 0 else { return }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }

    static func focused() -> AXUIElement? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &v) == .success,
              let v, CFGetTypeID(v) == AXUIElementGetTypeID()
        else { return nil }
        return (v as! AXUIElement)
    }

    static func read() -> CaretSnapshot {
        guard let el = focused() else { return CaretSnapshot() }
        return CaretSnapshot(focus: el, loc: caret(of: el))
    }

    static func caret(of el: AXUIElement) -> Int {
        var r: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, &r) == .success,
              let r, CFGetTypeID(r) == AXValueGetTypeID()
        else { return -1 }
        var range = CFRange()
        guard AXValueGetValue(r as! AXValue, .cfRange, &range) else { return -1 }
        return range.location + range.length
    }

    static func text(of el: AXUIElement) -> String? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &v) == .success else { return nil }
        return v as? String
    }
}

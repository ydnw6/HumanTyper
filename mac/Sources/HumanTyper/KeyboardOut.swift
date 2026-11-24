import Foundation
import CoreGraphics
import Carbon.HIToolbox

/// Sends keystrokes to whatever app has the keyboard focus, via Quartz events.
/// Text goes out as Unicode keyboard events (no keyboard-layout lookup); editing keys use their real key codes.
/// Every event is tagged with `marker`, so the input monitor can tell our keystrokes from the user's.
final class KeyboardOut {
    static let marker: Int64 = 0x4854_5950   // "HTYP"

    private let source = CGEventSource(stateID: .hidSystemState)

    func char(_ s: String) {
        var chars = Array(s.utf16)
        guard !chars.isEmpty else { return }
        for down in [true, false] {
            guard let ev = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down) else { continue }
            ev.flags = []
            ev.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
            post(ev)
        }
    }

    func enter(shift: Bool) { tap(UInt16(kVK_Return), flags: shift ? .maskShift : []) }
    func tab() { tap(UInt16(kVK_Tab)) }
    func backspace() { tap(UInt16(kVK_Delete)) }
    func space() { tap(UInt16(kVK_Space), text: " ") }
    func left() { tap(UInt16(kVK_LeftArrow), flags: [.maskNumericPad, .maskSecondaryFn]) }
    func right() { tap(UInt16(kVK_RightArrow), flags: [.maskNumericPad, .maskSecondaryFn]) }

    private func tap(_ key: UInt16, flags: CGEventFlags = [], text: String? = nil) {
        var chars = text.map { Array($0.utf16) } ?? []
        if flags.contains(.maskShift) { modifier(UInt16(kVK_Shift), down: true) }
        for down in [true, false] {
            guard let ev = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else { continue }
            ev.flags = flags
            if !chars.isEmpty { ev.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars) }
            post(ev)
            if down { usleep(UInt32.random(in: 8_000...25_000)) }
        }
        if flags.contains(.maskShift) { modifier(UInt16(kVK_Shift), down: false) }
    }

    private func modifier(_ key: UInt16, down: Bool) {
        guard let ev = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else { return }
        ev.flags = down ? .maskShift : []
        post(ev)
        usleep(UInt32.random(in: 6_000...15_000))
    }

    private func post(_ ev: CGEvent) {
        ev.setIntegerValueField(.eventSourceUserData, value: KeyboardOut.marker)
        ev.post(tap: .cghidEventTap)
    }
}

/// Temporarily switches the system input source to a plain keyboard layout, so a Chinese/Japanese input
/// method doesn't swallow our Unicode keystrokes as pinyin. Call on the main thread.
enum InputSourceSwitch {
    /// Returns the source to restore afterwards (nil if nothing was changed).
    static func switchToAsciiIfNeeded() -> TISInputSource? {
        guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        if let typePtr = TISGetInputSourceProperty(current, kTISPropertyInputSourceType) {
            let type = Unmanaged<CFString>.fromOpaque(typePtr).takeUnretainedValue()
            if CFEqual(type, kTISTypeKeyboardLayout) { return nil }   // already a plain layout
        }
        guard let ascii = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue() else { return nil }
        TISSelectInputSource(ascii)
        return current
    }

    static func restore(_ source: TISInputSource?) {
        if let source { TISSelectInputSource(source) }
    }
}

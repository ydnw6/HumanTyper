import Foundation
import CoreGraphics
import Carbon.HIToolbox

/// Sends keystrokes to whatever app has the keyboard focus, via Quartz events.
/// Standard mode: text goes out as Unicode keyboard events (no keyboard-layout lookup).
/// Key mode: every character is a real key press (US layout key code + Shift), the same signal a physical
/// keyboard gives, so it passes through remote-desktop / remote-control viewers; Chinese is then typed as
/// pinyin into the remote computer's input method by the engine.
/// Every event is tagged with `marker`, so the input monitor can tell our keystrokes from the user's.
final class KeyboardOut {
    static let marker: Int64 = 0x4854_5950   // "HTYP"

    private let source = CGEventSource(stateID: .hidSystemState)
    let isKeyMode: Bool

    init(keyMode: Bool = false) { isKeyMode = keyMode }

    func char(_ s: String) {
        if isKeyMode, let k = KeyboardOut.usKey(for: s) {
            keyPress(k.0, shift: k.1)
            return
        }
        unicodeChar(s)
    }

    /// Taps Shift on its own (toggles Chinese/English in most Chinese IMEs).
    func loneShift() {
        modifier(UInt16(kVK_Shift), flag: .maskShift, down: true)
        usleep(UInt32.random(in: 40_000...90_000))
        modifier(UInt16(kVK_Shift), flag: .maskShift, down: false)
    }

    /// Ctrl+Space (alternative IME toggle).
    func ctrlSpace() {
        modifier(UInt16(kVK_Control), flag: .maskControl, down: true)
        usleep(UInt32.random(in: 30_000...70_000))
        for down in [true, false] {
            guard let ev = CGEvent(keyboardEventSource: source, virtualKey: UInt16(kVK_Space), keyDown: down) else { continue }
            ev.flags = .maskControl
            post(ev)
            if down { usleep(UInt32.random(in: 25_000...70_000)) }
        }
        usleep(UInt32.random(in: 20_000...50_000))
        modifier(UInt16(kVK_Control), flag: .maskControl, down: false)
    }

    /// A real key press, optionally with Shift held (key mode).
    private func keyPress(_ key: UInt16, shift: Bool) {
        if shift {
            modifier(UInt16(kVK_Shift), flag: .maskShift, down: true)
            usleep(UInt32.random(in: 25_000...70_000))
        }
        for down in [true, false] {
            guard let ev = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else { continue }
            ev.flags = shift ? .maskShift : []
            post(ev)
            if down { usleep(UInt32.random(in: 25_000...80_000)) }   // key hold time
        }
        if shift {
            usleep(UInt32.random(in: 15_000...50_000))
            modifier(UInt16(kVK_Shift), flag: .maskShift, down: false)
        }
    }

    private func unicodeChar(_ s: String) {
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
    func space() { tap(UInt16(kVK_Space), text: isKeyMode ? nil : " ") }
    func left() { tap(UInt16(kVK_LeftArrow), flags: [.maskNumericPad, .maskSecondaryFn]) }
    func right() { tap(UInt16(kVK_RightArrow), flags: [.maskNumericPad, .maskSecondaryFn]) }

    private func tap(_ key: UInt16, flags: CGEventFlags = [], text: String? = nil) {
        var chars = text.map { Array($0.utf16) } ?? []
        if flags.contains(.maskShift) { modifier(UInt16(kVK_Shift), flag: .maskShift, down: true) }
        for down in [true, false] {
            guard let ev = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else { continue }
            ev.flags = flags
            if !chars.isEmpty { ev.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars) }
            post(ev)
            if down { usleep(UInt32.random(in: isKeyMode ? 25_000...80_000 : 8_000...25_000)) }
        }
        if flags.contains(.maskShift) { modifier(UInt16(kVK_Shift), flag: .maskShift, down: false) }
    }

    /// Modifier keys go out as flags-changed events (Quartz picks the type from the key code).
    private func modifier(_ key: UInt16, flag: CGEventFlags, down: Bool) {
        guard let ev = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else { return }
        ev.type = .flagsChanged
        ev.flags = down ? flag : []
        post(ev)
        usleep(UInt32.random(in: 6_000...15_000))
    }

    // ------------------------------------------------------------------ character → key (US layout)

    /// True if the character can be produced by a key on a US keyboard.
    static func canType(_ s: String) -> Bool { usKey(for: s) != nil }

    /// The key (ANSI key code) and Shift state that produce `s` on a US layout. Remote machines almost
    /// always use this layout for typing pinyin. Caps Lock flips letters.
    static func usKey(for s: String) -> (UInt16, Bool)? {
        guard s.count == 1, let c = s.first, c.isASCII else { return nil }
        let key: UInt16
        var shift: Bool
        if let k = unshifted[c] { key = k; shift = false }
        else if let k = shifted[c] { key = k; shift = true }
        else { return nil }
        if c.isLetter && CGEventSource.flagsState(.hidSystemState).contains(.maskAlphaShift) { shift.toggle() }
        return (key, shift)
    }

    private static let usRows: [(Character, Character, Int)] = [
        ("`", "~", kVK_ANSI_Grave), ("1", "!", kVK_ANSI_1), ("2", "@", kVK_ANSI_2), ("3", "#", kVK_ANSI_3),
        ("4", "$", kVK_ANSI_4), ("5", "%", kVK_ANSI_5), ("6", "^", kVK_ANSI_6), ("7", "&", kVK_ANSI_7),
        ("8", "*", kVK_ANSI_8), ("9", "(", kVK_ANSI_9), ("0", ")", kVK_ANSI_0), ("-", "_", kVK_ANSI_Minus),
        ("=", "+", kVK_ANSI_Equal),
        ("q", "Q", kVK_ANSI_Q), ("w", "W", kVK_ANSI_W), ("e", "E", kVK_ANSI_E), ("r", "R", kVK_ANSI_R),
        ("t", "T", kVK_ANSI_T), ("y", "Y", kVK_ANSI_Y), ("u", "U", kVK_ANSI_U), ("i", "I", kVK_ANSI_I),
        ("o", "O", kVK_ANSI_O), ("p", "P", kVK_ANSI_P), ("[", "{", kVK_ANSI_LeftBracket),
        ("]", "}", kVK_ANSI_RightBracket), ("\\", "|", kVK_ANSI_Backslash),
        ("a", "A", kVK_ANSI_A), ("s", "S", kVK_ANSI_S), ("d", "D", kVK_ANSI_D), ("f", "F", kVK_ANSI_F),
        ("g", "G", kVK_ANSI_G), ("h", "H", kVK_ANSI_H), ("j", "J", kVK_ANSI_J), ("k", "K", kVK_ANSI_K),
        ("l", "L", kVK_ANSI_L), (";", ":", kVK_ANSI_Semicolon), ("'", "\"", kVK_ANSI_Quote),
        ("z", "Z", kVK_ANSI_Z), ("x", "X", kVK_ANSI_X), ("c", "C", kVK_ANSI_C), ("v", "V", kVK_ANSI_V),
        ("b", "B", kVK_ANSI_B), ("n", "N", kVK_ANSI_N), ("m", "M", kVK_ANSI_M), (",", "<", kVK_ANSI_Comma),
        (".", ">", kVK_ANSI_Period), ("/", "?", kVK_ANSI_Slash), (" ", " ", kVK_Space),
    ]
    private static let unshifted: [Character: UInt16] = Dictionary(usRows.map { ($0.0, UInt16($0.2)) }, uniquingKeysWith: { a, _ in a })
    private static let shifted: [Character: UInt16] = Dictionary(usRows.map { ($0.1, UInt16($0.2)) }, uniquingKeysWith: { a, _ in a })

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

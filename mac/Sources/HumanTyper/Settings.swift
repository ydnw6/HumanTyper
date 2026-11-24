import Foundation
import Carbon.HIToolbox

/// A global hotkey: Carbon virtual key code + Carbon modifier mask (cmdKey, optionKey, controlKey, shiftKey).
struct HotKey: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let none = HotKey(keyCode: UInt32.max, modifiers: 0)
    var isNone: Bool { keyCode == UInt32.max }

    var displayName: String {
        if isNone { return "无" }
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + KeyNames.name(for: keyCode)
    }
}

enum KeyNames {
    private static let table: [UInt32: String] = {
        var t: [UInt32: String] = [
            UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3", UInt32(kVK_F4): "F4",
            UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6", UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8",
            UInt32(kVK_F9): "F9", UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12",
            UInt32(kVK_F13): "F13", UInt32(kVK_F14): "F14", UInt32(kVK_F15): "F15", UInt32(kVK_F16): "F16",
            UInt32(kVK_F17): "F17", UInt32(kVK_F18): "F18", UInt32(kVK_F19): "F19", UInt32(kVK_F20): "F20",
            UInt32(kVK_Space): "Space", UInt32(kVK_Return): "Return", UInt32(kVK_Tab): "Tab",
            UInt32(kVK_Escape): "Esc", UInt32(kVK_Home): "Home", UInt32(kVK_End): "End",
            UInt32(kVK_PageUp): "PageUp", UInt32(kVK_PageDown): "PageDown",
            UInt32(kVK_LeftArrow): "←", UInt32(kVK_RightArrow): "→", UInt32(kVK_UpArrow): "↑", UInt32(kVK_DownArrow): "↓",
        ]
        let letters: [(Int, String)] = [
            (kVK_ANSI_A, "A"), (kVK_ANSI_B, "B"), (kVK_ANSI_C, "C"), (kVK_ANSI_D, "D"), (kVK_ANSI_E, "E"),
            (kVK_ANSI_F, "F"), (kVK_ANSI_G, "G"), (kVK_ANSI_H, "H"), (kVK_ANSI_I, "I"), (kVK_ANSI_J, "J"),
            (kVK_ANSI_K, "K"), (kVK_ANSI_L, "L"), (kVK_ANSI_M, "M"), (kVK_ANSI_N, "N"), (kVK_ANSI_O, "O"),
            (kVK_ANSI_P, "P"), (kVK_ANSI_Q, "Q"), (kVK_ANSI_R, "R"), (kVK_ANSI_S, "S"), (kVK_ANSI_T, "T"),
            (kVK_ANSI_U, "U"), (kVK_ANSI_V, "V"), (kVK_ANSI_W, "W"), (kVK_ANSI_X, "X"), (kVK_ANSI_Y, "Y"),
            (kVK_ANSI_Z, "Z"), (kVK_ANSI_0, "0"), (kVK_ANSI_1, "1"), (kVK_ANSI_2, "2"), (kVK_ANSI_3, "3"),
            (kVK_ANSI_4, "4"), (kVK_ANSI_5, "5"), (kVK_ANSI_6, "6"), (kVK_ANSI_7, "7"), (kVK_ANSI_8, "8"),
            (kVK_ANSI_9, "9"),
        ]
        for (k, n) in letters { t[UInt32(k)] = n }
        return t
    }()

    static func name(for keyCode: UInt32) -> String { table[keyCode] ?? "键\(keyCode)" }
}

/// All user settings. Stored as JSON in UserDefaults; keys missing from an older file fall back to the defaults.
struct Settings: Codable, Equatable {
    // 速度
    var enWpm: Int = 55              // 英文 词/分钟
    var zhCpm: Int = 80              // 中文 字/分钟
    var variance: Int = 30           // 节奏波动 %

    // 错字
    var typoRate: Double = 3.0       // 每个字符出错概率 %
    var maxNoticeDelay: Int = 3      // 最多再打几个字才发现错误

    // 思考停顿
    var thinkEnabled: Bool = true
    var wordEveryMin: Int = 4, wordEveryMax: Int = 12
    var wordPauseMin: Double = 0.4, wordPauseMax: Double = 1.8
    var sentEveryMin: Int = 1, sentEveryMax: Int = 3
    var sentPauseMin: Double = 1.5, sentPauseMax: Double = 5.0
    var paraPauseMin: Double = 2.5, paraPauseMax: Double = 7.0
    var punctPause: Bool = true

    // 控制
    var autoPause: Bool = true
    var proofread: Bool = true
    var switchToAsciiInput: Bool = true   // 开始时临时切到英文键盘布局，避免输入法拦截按键
    var countdown: Int = 3
    var newlineMode: Int = 0              // 0 = Return, 1 = Shift+Return
    var hideOnStart: Bool = false
    var topMost: Bool = false
    var showOverlay: Bool = true
    var noticeHiddenVersion: String = ""
    var overlayX: Double = -99999, overlayY: Double = -99999

    var startPauseKey = HotKey(keyCode: UInt32(kVK_F8), modifiers: 0)
    var stopKey = HotKey(keyCode: UInt32(kVK_F9), modifiers: 0)
    var restartKey = HotKey(keyCode: UInt32(kVK_F10), modifiers: 0)

    private static let defaultsKey = "HumanTyper.settings"

    static func load() -> Settings {
        let def = Settings()
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let stored = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let defData = try? JSONEncoder().encode(def),
              var merged = (try? JSONSerialization.jsonObject(with: defData)) as? [String: Any]
        else { return def }
        for (k, v) in stored where merged[k] != nil { merged[k] = v }
        guard let m = try? JSONSerialization.data(withJSONObject: merged),
              let s = try? JSONDecoder().decode(Settings.self, from: m)
        else { return def }
        return s
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Settings.defaultsKey)
        }
    }
}

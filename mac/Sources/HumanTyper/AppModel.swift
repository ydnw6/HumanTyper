import AppKit
import SwiftUI
import Carbon.HIToolbox
import UniformTypeIdentifiers

enum FreeNotice {
    static let repoUrl = URL(string: "https://github.com/ydnw6/HumanTyper")!
    static let issuesUrl = URL(string: "https://github.com/ydnw6/HumanTyper/issues")!
    static let sponsorUrl = URL(string: "https://ifdian.net/a/ydnw6")!
    static let qq = "959649446"
    static let oneLine = "本软件永久免费开源，付费购买请退款并举报卖家"

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    /// The "this software is free forever" notice. Returns true if the user ticked "don't show again".
    @discardableResult
    static func show(startup: Bool) -> Bool {
        let a = NSAlert()
        a.messageText = "本软件永久免费、开源"
        a.informativeText = """
        HumanTyper 是免费的开源软件（MIT 许可证），不收取任何费用，也没有付费版、会员或激活码。

        如果你是花钱买到的，说明你被骗了：请立即向卖家所在平台申请退款，并举报该卖家。
        """
        a.accessoryView = links()
        a.addButton(withTitle: "我知道了")
        a.addButton(withTitle: "爱发电赞助 ♥")
        if startup {
            a.showsSuppressionButton = true
            a.suppressionButton?.title = "这个版本不再提示"
        }
        if a.runModal() == .alertSecondButtonReturn { NSWorkspace.shared.open(sponsorUrl) }
        return a.suppressionButton?.state == .on
    }

    /// Official address, issue tracker and QQ as clickable rows, plus the voluntary-sponsor note.
    private static func links() -> NSView {
        func label(_ s: String, secondary: Bool = false) -> NSTextField {
            let t = NSTextField(wrappingLabelWithString: s)
            t.font = .systemFont(ofSize: secondary ? 11 : 12)
            if secondary { t.textColor = .secondaryLabelColor }
            return t
        }
        func link(_ title: String, _ action: @escaping () -> Void) -> NSButton {
            let b = ClosureButton(title: title, action: action)
            b.isBordered = false
            b.attributedTitle = NSAttributedString(string: title, attributes: [
                .foregroundColor: NSColor.linkColor, .font: NSFont.systemFont(ofSize: 12),
                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ])
            b.setContentHuggingPriority(.required, for: .horizontal)
            return b
        }
        func row(_ name: String, _ control: NSView) -> NSStackView {
            let r = NSStackView(views: [label(name), control])
            r.spacing = 4
            return r
        }

        let copy = ClosureButton(title: "复制", action: {})
        copy.bezelStyle = .rounded
        copy.controlSize = .small
        copy.onClick = { [weak copy] in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(qq, forType: .string)
            copy?.title = "已复制"
        }
        let qqRow = NSStackView(views: [label("QQ：\(qq)"), copy])
        qqRow.spacing = 6

        let stack = NSStackView(views: [
            label("官方下载、问题反馈、功能建议："),
            row("GitHub：", link(repoUrl.absoluteString.replacingOccurrences(of: "https://", with: "")) { NSWorkspace.shared.open(repoUrl) }),
            row("问题反馈（Issues）：", link("github.com/ydnw6/HumanTyper/issues") { NSWorkspace.shared.open(issuesUrl) }),
            qqRow,
            label("觉得好用，可以在爱发电自愿赞助作者（ifdian.net/a/ydnw6），不赞助也能使用全部功能。", secondary: true),
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.setCustomSpacing(10, after: qqRow)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let width: CGFloat = 340
        stack.widthAnchor.constraint(equalToConstant: width).isActive = true
        stack.layoutSubtreeIfNeeded()
        stack.frame = NSRect(origin: .zero, size: NSSize(width: width, height: stack.fittingSize.height))
        stack.translatesAutoresizingMaskIntoConstraints = true
        return stack
    }
}

/// NSButton that runs a closure (NSAlert accessory views have no controller to act as target).
final class ClosureButton: NSButton {
    var onClick: () -> Void
    init(title: String, action: @escaping () -> Void) {
        onClick = action
        super.init(frame: .zero)
        self.title = title
        target = self
        self.action = #selector(fire)
    }
    required init?(coder: NSCoder) { fatalError("not used") }
    @objc private func fire() { onClick() }
}

/// UI state + glue between the window, the hotkeys, the overlay and the typing engine. Main thread only.
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var text = ""
    @Published var settings = Settings.load() {
        didSet {
            guard settings != oldValue else { return }
            settings.save()
            if settings.startPauseKey != oldValue.startPauseKey || settings.stopKey != oldValue.stopKey ||
                settings.restartKey != oldValue.restartKey { registerHotKeys() }
            if settings.topMost != oldValue.topMost { applyTopMost() }
            if settings.showOverlay != oldValue.showOverlay && isBusy {
                if settings.showOverlay { overlay.show() } else { overlay.hide() }
            }
        }
    }
    @Published var state: EngineState = .idle
    @Published var status = "就绪 — " + FreeNotice.oneLine
    @Published var done = 0
    @Published var total = 0
    @Published var countdownLeft: Int?
    @Published var trusted = CaretProbe.isTrusted

    private(set) var units: [String] = []
    private(set) var startedAt = Date()

    let engine = TypingEngine()
    private let monitor = InputMonitor()
    private var countdownTimer: Timer?
    private var trustTimer: Timer?
    private var savedSource: TISInputSource?
    private lazy var overlay = OverlayController(model: self)
    private let ownPid = ProcessInfo.processInfo.processIdentifier

    var isBusy: Bool { [.running, .thinking, .paused, .proofreading].contains(state) }
    var isPaused: Bool { state == .paused }
    var percent: Int { total > 0 ? Int((Double(done) * 100 / Double(total)).rounded(.down)) : 0 }

    var estimateText: String {
        let n = TypingEngine.split(text).count
        let sec = TypingEngine.estimate(text, settings)
        return "\(n) 字 · 预计 \(AppModel.duration(sec))"
    }

    static func duration(_ sec: Double) -> String {
        let s = Int(sec.rounded())
        if s < 60 { return "\(s) 秒" }
        if s < 3600 { return "\(s / 60) 分 \(s % 60) 秒" }
        return "\(s / 3600) 小时 \(s % 3600 / 60) 分"
    }

    private init() {
        engine.onState = { [weak self] run, st, msg in
            DispatchQueue.main.async { self?.engineState(run, st, msg) }
        }
        engine.onProgress = { [weak self] run, d, t in
            DispatchQueue.main.async { self?.engineProgress(run, d, t) }
        }
    }

    // ------------------------------------------------------------------ lifecycle

    func launched() {
        registerHotKeys()
        applyTopMost()
        if settings.noticeHiddenVersion != FreeNotice.appVersion {
            if FreeNotice.show(startup: true) { settings.noticeHiddenVersion = FreeNotice.appVersion }
        }
        if !CaretProbe.isTrusted { CaretProbe.requestTrust() }
        // Pick up the permission as soon as the user grants it in System Settings.
        trustTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            let t = CaretProbe.isTrusted
            if self?.trusted != t { self?.trusted = t }
        }
    }

    func registerHotKeys() {
        HotKeyCenter.shared.register([
            (settings.startPauseKey, { [weak self] in self?.hotkeyStartPause() }),
            (settings.stopKey, { [weak self] in self?.stop() }),
            (settings.restartKey, { [weak self] in self?.restart() }),
        ])
    }

    func applyTopMost() {
        for w in NSApp.windows where !(w is NSPanel) {
            w.level = settings.topMost ? .floating : .normal
        }
    }

    func openAccessibilitySettings() {
        CaretProbe.requestTrust()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Clears a stale Accessibility entry (left by an older build) and asks again. No admin rights needed.
    func resetAccessibility() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        p.arguments = ["reset", "Accessibility", Bundle.main.bundleIdentifier ?? "io.github.ydnw6.HumanTyper"]
        try? p.run()
        p.waitUntilExit()
        status = "已清除旧授权 — 请在弹出的系统设置里重新打开 HumanTyper 的开关"
        openAccessibilitySettings()
    }

    // ------------------------------------------------------------------ commands

    /// "开始" button: countdown, then type into whatever has focus when it ends.
    func startWithCountdown() {
        guard !isBusy, countdownLeft == nil, checkReady() else { return }
        let n = max(0, settings.countdown)
        if settings.hideOnStart { NSApp.hide(nil) }
        if n == 0 { finishCountdown(); return }
        countdownLeft = n
        status = "\(n) 秒后开始 — 请点击要输入的位置（按 \(settings.stopKey.displayName) 取消）"
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let left = self.countdownLeft else { return }
            if left <= 1 { self.finishCountdown() }
            else {
                self.countdownLeft = left - 1
                self.status = "\(left - 1) 秒后开始 — 请点击要输入的位置（按 \(self.settings.stopKey.displayName) 取消）"
            }
        }
    }

    private func finishCountdown() {
        cancelCountdown()
        beginOnFrontApp()
    }

    private func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownLeft = nil
    }

    /// Start/pause hotkey: idle → start right here; running → pause; paused → continue at the current caret.
    func hotkeyStartPause() {
        if countdownLeft != nil { cancelCountdown(); beginOnFrontApp(); return }
        if isBusy { engine.togglePause(); return }
        guard checkReady() else { return }
        beginOnFrontApp()
    }

    func togglePause() {
        if isBusy { engine.togglePause() }
    }

    func stop() {
        if countdownLeft != nil {
            cancelCountdown()
            status = "已取消"
            if settings.hideOnStart { NSApp.unhide(nil) }
            return
        }
        engine.stop()
    }

    func restart() {
        cancelCountdown()
        guard checkReady() else { return }
        if engine.isBusy { engine.stopAndWait() }
        if engine.isBusy { status = "上一次输入还没停下，请稍后再试"; return }
        beginOnFrontApp()
    }

    func openFile() {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.plainText, .text]
        p.allowsOtherFileTypes = true
        guard p.runModal() == .OK, let url = p.url, let data = try? Data(contentsOf: url) else { return }
        if let s = String(data: data, encoding: .utf8) { text = s; return }
        let gb = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        if let s = String(data: data, encoding: gb) { text = s; return }
        status = "无法识别文件编码（支持 UTF-8 / GBK）"
    }

    // ------------------------------------------------------------------ run

    private func checkReady() -> Bool {
        if text.isEmpty { status = "请先输入或粘贴要打的文字"; return false }
        if !CaretProbe.isTrusted {
            trusted = false
            status = "需要“辅助功能”权限才能模拟键盘 — 请在系统设置中允许 HumanTyper，然后重试"
            openAccessibilitySettings()
            return false
        }
        return true
    }

    private func beginOnFrontApp() {
        let pid = CaretProbe.frontPid()
        if pid == 0 || pid == ownPid {
            status = "HumanTyper 自己在前台 — 请先点击要输入的位置（其他程序里），再按 \(settings.startPauseKey.displayName) 开始"
            NSApp.unhide(nil)
            return
        }
        units = TypingEngine.split(text)
        done = 0
        total = units.count
        startedAt = Date()
        if settings.switchToAsciiInput && savedSource == nil { savedSource = InputSourceSwitch.switchToAsciiIfNeeded() }
        monitor.start { [weak self] in self?.engine.notifyUserInput() }
        state = .running
        if settings.showOverlay { overlay.show() }
        engine.start(text: text, settings: settings, target: pid)
    }

    private func engineState(_ run: Int, _ st: EngineState, _ msg: String) {
        guard run == engine.runId else { return }
        state = st
        status = msg
        if st == .finished || st == .stopped {
            monitor.stop()
            InputSourceSwitch.restore(savedSource)
            savedSource = nil
            NSApp.dockTile.badgeLabel = nil
            if st == .finished { done = total }
            overlay.hide(after: st == .finished ? 2.5 : 0.8)
        }
    }

    private func engineProgress(_ run: Int, _ d: Int, _ t: Int) {
        guard run == engine.runId else { return }
        done = d
        total = t
        NSApp.dockTile.badgeLabel = isBusy ? "\(percent)%" : nil
    }

    // ------------------------------------------------------------------ overlay helpers

    var stateTitle: String {
        switch state {
        case .idle: return "就绪"
        case .running: return "正在输入"
        case .thinking: return "思考中"
        case .paused: return "已暂停"
        case .proofreading: return "核对中"
        case .finished: return "完成"
        case .stopped: return "已停止"
        }
    }

    var remainingText: String {
        guard done > 0, total > done else { return "" }
        let elapsed = Date().timeIntervalSince(startedAt)
        let left = elapsed / Double(done) * Double(total - done)
        return "剩余约 " + AppModel.duration(left)
    }

    func overlayMoved(to p: NSPoint) {
        settings.overlayX = Double(p.x)
        settings.overlayY = Double(p.y)
    }

    func overlayClosedByUser() { overlay.hide() }
}

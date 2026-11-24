import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            if !model.trusted { permissionBanner }
            HStack(alignment: .top, spacing: 14) {
                editor
                ScrollView { SettingsPane().padding(.trailing, 8) }
                    .frame(width: 360)
            }
            .padding(14)
            Divider()
            statusBar
        }
    }

    private var permissionBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
            Text("需要在“系统设置 → 隐私与安全性 → 辅助功能”里允许 HumanTyper，才能模拟键盘输入。")
            Spacer()
            Button("打开设置") { model.openAccessibilitySettings() }
        }
        .padding(10)
        .background(Color.orange.opacity(0.15))
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("要输入的文字").font(.headline)
                Spacer()
                Text(model.estimateText).foregroundColor(.secondary).font(.callout)
                Button("打开文件…") { model.openFile() }.disabled(model.isBusy)
            }
            TextEditor(text: $model.text)
                .font(.system(size: 14))
                .disabled(model.isBusy)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
            HStack(spacing: 8) {
                Button(model.countdownLeft.map { "倒计时 \($0)…" } ?? "开始") { model.startWithCountdown() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.isBusy || model.countdownLeft != nil)
                Button(model.isPaused ? "继续" : "暂停") { model.togglePause() }
                    .disabled(!model.isBusy)
                Button("停止") { model.stop() }
                    .disabled(!model.isBusy && model.countdownLeft == nil)
                Button("重新开始") { model.restart() }
                Spacer()
                Text("\(model.settings.startPauseKey.displayName) 开始/暂停 · \(model.settings.stopKey.displayName) 停止 · \(model.settings.restartKey.displayName) 重新开始")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            Text(model.status).lineLimit(1).truncationMode(.tail)
            Spacer()
            if model.isBusy || model.state == .finished {
                ProgressView(value: Double(model.done), total: Double(max(1, model.total)))
                    .frame(width: 160)
                Text("\(model.percent)%").monospacedDigit()
            }
            Button(FreeNotice.oneLine) { FreeNotice.show(startup: false) }
                .buttonStyle(.link)
                .font(.caption)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

// MARK: - settings

struct SettingsPane: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let s = $model.settings
        VStack(alignment: .leading, spacing: 12) {
            GroupBox(label: Text("速度")) {
                VStack(spacing: 6) {
                    IntRow(title: "英文速度", value: s.enWpm, range: 5...200, step: 5, unit: "WPM")
                    IntRow(title: "中文速度", value: s.zhCpm, range: 5...300, step: 5, unit: "字/分")
                    IntRow(title: "节奏波动", value: s.variance, range: 0...100, step: 5, unit: "%")
                }.padding(4)
            }
            GroupBox(label: Text("错字")) {
                VStack(spacing: 6) {
                    DoubleRow(title: "错字频率", value: s.typoRate, range: 0...20, step: 0.5, unit: "%")
                    IntRow(title: "发现错误前最多多打", value: s.maxNoticeDelay, range: 0...3, unit: "个字")
                }.padding(4)
            }
            GroupBox(label: Text("思考停顿")) {
                VStack(spacing: 6) {
                    Toggle("启用思考停顿", isOn: s.thinkEnabled).frame(maxWidth: .infinity, alignment: .leading)
                    Group {
                        IntRow(title: "每隔词数（最少）", value: s.wordEveryMin, range: 1...50)
                        IntRow(title: "每隔词数（最多）", value: s.wordEveryMax, range: 1...50)
                        DoubleRow(title: "词间停顿最短", value: s.wordPauseMin, range: 0...10, step: 0.1, unit: "秒")
                        DoubleRow(title: "词间停顿最长", value: s.wordPauseMax, range: 0...10, step: 0.1, unit: "秒")
                        IntRow(title: "每隔句数（最少）", value: s.sentEveryMin, range: 1...20)
                        IntRow(title: "每隔句数（最多）", value: s.sentEveryMax, range: 1...20)
                        DoubleRow(title: "句间停顿最短", value: s.sentPauseMin, range: 0...30, step: 0.5, unit: "秒")
                        DoubleRow(title: "句间停顿最长", value: s.sentPauseMax, range: 0...30, step: 0.5, unit: "秒")
                        DoubleRow(title: "换段停顿最短", value: s.paraPauseMin, range: 0...60, step: 0.5, unit: "秒")
                        DoubleRow(title: "换段停顿最长", value: s.paraPauseMax, range: 0...60, step: 0.5, unit: "秒")
                    }
                    .disabled(!model.settings.thinkEnabled)
                    Toggle("逗号、分号后稍作停顿", isOn: s.punctPause).frame(maxWidth: .infinity, alignment: .leading)
                }.padding(4)
            }
            GroupBox(label: Text("控制")) {
                VStack(alignment: .leading, spacing: 6) {
                    IntRow(title: "倒计时", value: s.countdown, range: 0...30, unit: "秒")
                    Picker("换行方式", selection: s.newlineMode) {
                        Text("Return").tag(0)
                        Text("Shift+Return").tag(1)
                    }
                    Picker("输入方式", selection: s.inputMode) {
                        Text("标准（本机程序）").tag(0)
                        Text("键盘按键（远程桌面 / 远控软件）").tag(1)
                    }
                    if model.settings.inputMode == 1 {
                        Group {
                            Picker("目标输入法开始时为", selection: s.remoteImeChinese) {
                                Text("中文模式").tag(true)
                                Text("英文模式").tag(false)
                            }
                            Picker("中英切换键", selection: s.imeToggleKey) {
                                Text("Shift").tag(0)
                                Text("Ctrl+Space").tag(1)
                            }
                            Text("键盘模式发出和实体键盘一样的按键，中文转成拼音交给目标电脑的中文输入法打出。请先把目标电脑切到中文输入法，并选对它现在是中文还是英文模式。")
                                .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Group {
                        Toggle("光标离开原位置/程序时自动暂停", isOn: s.autoPause)
                        Toggle("打完后从头核对一遍", isOn: s.proofread)
                        Toggle("打字时临时切换到英文键盘（避免中文输入法拦截）", isOn: s.switchToAsciiInput)
                        Toggle("显示进度悬浮窗", isOn: s.showOverlay)
                        Toggle("点“开始”后隐藏本窗口", isOn: s.hideOnStart)
                        Toggle("窗口置顶", isOn: s.topMost)
                    }
                    Group {
                        HotkeyRow(title: "开始 / 暂停 / 继续", key: s.startPauseKey)
                        HotkeyRow(title: "停止", key: s.stopKey)
                        HotkeyRow(title: "重新开始", key: s.restartKey)
                    }
                    Text("笔记本键盘上 F8–F10 默认是媒体键，需要同时按 fn；也可以点击上面的按钮改成别的组合键（Delete 清除）。")
                        .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.padding(4)
            }
        }
    }
}

struct IntRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    var unit: String = ""

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(value) \(unit)").monospacedDigit().foregroundColor(.secondary)
            Stepper("", value: $value, in: range, step: step).labelsHidden()
        }
    }
}

struct DoubleRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0.1
    var unit: String = ""

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(String(format: "%.1f %@", value, unit)).monospacedDigit().foregroundColor(.secondary)
            Stepper("", value: $value, in: range, step: step).labelsHidden()
        }
    }
}

/// Click, then press the new key combination. Delete clears, Esc cancels.
struct HotkeyRow: View {
    let title: String
    @Binding var key: HotKey
    @EnvironmentObject var model: AppModel
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button(recording ? "请按下新的快捷键…" : key.displayName) {
                recording ? endRecording() : beginRecording()
            }
            .frame(minWidth: 120)
        }
    }

    private func beginRecording() {
        recording = true
        HotKeyCenter.shared.unregisterAll()   // so the current hotkey can be pressed and captured
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            switch Int(e.keyCode) {
            case 53: break                                          // Esc: cancel
            case 51, 117: key = .none                               // Delete / Forward Delete: clear
            default:
                key = HotKey(keyCode: UInt32(e.keyCode), modifiers: HotKeyCenter.carbonModifiers(e.modifierFlags))
            }
            endRecording()
            return nil
        }
    }

    private func endRecording() {
        recording = false
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
        model.registerHotKeys()
    }
}

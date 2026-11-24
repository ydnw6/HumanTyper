import Foundation
import ApplicationServices

enum EngineState { case idle, running, thinking, paused, proofreading, finished, stopped }

/// Thread-safe box for values shared between the UI thread and the typing thread.
@propertyWrapper
final class Locked<T> {
    private var value: T
    private let lock = NSLock()
    init(wrappedValue: T) { value = wrappedValue }
    var wrappedValue: T {
        get { lock.lock(); defer { lock.unlock() }; return value }
        set { lock.lock(); value = newValue; lock.unlock() }
    }
}

private struct Cancelled: Error {}

/// Types text into the focused app the way a person would: uneven rhythm, typos that get noticed and
/// corrected, pauses to think between words / sentences / paragraphs, and an IME-like cadence for Chinese.
/// Pauses itself when the user takes over the keyboard/mouse or leaves the target app, and resumes once
/// the caret is back where it was. Port of the Windows TypingEngine.
final class TypingEngine {
    var onState: ((Int, EngineState, String) -> Void)?       // (runId, state, message) — called on the typing thread
    var onProgress: ((Int, Int, Int) -> Void)?               // (runId, done, total)

    @Locked private(set) var runId = 0
    @Locked private var stopFlag = false
    @Locked private var manualPause = false
    @Locked private var rebaseline = false
    @Locked private var autoPaused = false
    @Locked private var interfered = false
    @Locked private var lastUserInputMs: Int64 = 0
    @Locked private var busy = false
    @Locked private(set) var target: pid_t = 0

    private var s = Settings()
    private var u: [String] = []
    private var myRun = 0

    private var lastKeyMs: Int64 = 0
    private var lastSampleMs: Int64 = 0
    private var lastProgressMs: Int64 = 0

    private var targetFocus: AXUIElement?
    private var baseline = CaretSnapshot()
    private var unsampled = 0        // net characters typed since baseline was sampled (backspace = -1)
    private var catchUp = 0          // Right-arrow presses needed after resuming at baseline
    private var caretTracks = false  // we've seen the caret move as we typed (so its position is meaningful)

    private var flow = 1.0
    private var wordsLeft = 0, sentencesLeft = 0
    private var pendingSentence = false
    private var noTypoAt = -1
    private var fixing = false
    private var proofMsg: String?
    private var startFocus: AXUIElement?
    private var startLoc = -1

    private let kb = KeyboardOut()
    private let ownPid = ProcessInfo.processInfo.processIdentifier
    private var now: Int64 { Int64(ProcessInfo.processInfo.systemUptime * 1000) }

    var isBusy: Bool { busy }
    var isPaused: Bool { manualPause || autoPaused }
    var isManualPaused: Bool { manualPause }

    // ------------------------------------------------------------------ control API

    func start(text: String, settings: Settings, target pid: pid_t) {
        if busy { return }
        busy = true
        runId += 1
        s = settings
        u = TypingEngine.split(text)
        target = pid
        stopFlag = false; manualPause = false; rebaseline = false; autoPaused = false; interfered = false
        unsampled = 0; catchUp = 0; caretTracks = false
        flow = 1.0; pendingSentence = false; noTypoAt = -1; fixing = false
        resetWordCounter(); resetSentenceCounter()
        let t = Thread { [weak self] in self?.worker() }
        t.name = "HumanTyper"
        t.qualityOfService = .userInteractive
        t.start()
    }

    /// Running → manual pause. Paused (any reason) → resume at the current caret.
    func togglePause() {
        guard busy else { return }
        if manualPause || autoPaused { rebaseline = true; manualPause = false }
        else { manualPause = true }
    }

    func stop() { stopFlag = true }

    func stopAndWait(timeout: TimeInterval = 2) {
        stopFlag = true
        let end = Date().addingTimeInterval(timeout)
        while busy && Date() < end { usleep(10_000) }
    }

    /// Called (on the main thread) for physical keyboard / mouse input in other apps.
    func notifyUserInput() {
        guard busy, !manualPause, target != 0 else { return }
        if CaretProbe.frontPid() != target { return }   // other apps are caught by the foreground check
        lastUserInputMs = now
        interfered = true
    }

    // ------------------------------------------------------------------ worker

    private func worker() {
        myRun = runId
        var final = EngineState.finished
        defer { busy = false }
        do {
            CaretProbe.enableAccessibility(for: target)
            let snap = CaretProbe.read()
            targetFocus = snap.focus
            baseline = snap
            startFocus = snap.focus
            startLoc = snap.loc
            lastSampleMs = now
            proofMsg = nil
            report(.running, "正在输入…")
            progress(0, force: true)
            try run()
            progress(u.count, force: true)
            if s.proofread { try proofread() }
        } catch is Cancelled {
            final = .stopped
        } catch {
            report(.stopped, "出错：\(error.localizedDescription)")
            return
        }
        report(final, final == .finished ? "输入完成" + (proofMsg.map { " — " + $0 } ?? "") : "已停止")
    }

    private func run() throws {
        let n = u.count
        var i = 0
        while i < n {
            let unit = u[i]
            if TypingEngine.isCjk(unit) {
                var runEnd = i
                while runEnd < n && TypingEngine.isCjk(u[runEnd]) { runEnd += 1 }
                let len = pickChunkLength(runEnd - i)
                try typeCjkChunk(i, len)
                i += len
                progress(i, force: false)
                try afterWord(i - 1)
                try afterUnit(i - 1)
                continue
            }

            if i != noTypoAt && TypingEngine.isTypoCandidate(unit) && chance(s.typoRate / 100) {
                let ni = try doLatinTypo(i)
                if ni >= 0 {
                    noTypoAt = ni
                    for k in i..<ni { try afterUnit(k) }
                    i = ni
                    progress(i, force: false)
                    continue
                }
            }

            try wait(latinDelay(i))
            try key(unit)
            i += 1
            progress(i, force: false)
            try afterUnit(i - 1)
        }
    }

    // ------------------------------------------------------------------ rhythm

    private var latinBaseMs: Double { 60000.0 / (Double(max(5, s.enWpm)) * 5.0) }
    private var cjkBaseMs: Double { 60000.0 / Double(max(5, s.zhCpm)) }

    private static let fastBigrams: Set<String> = [
        "th","he","in","er","an","re","on","at","en","nd","ti","es","or","te","of","ed","is","it","al","ar",
        "st","to","nt","ng","se","ha","as","ou","io","le","ve","co","me","de","hi","ri","ro","ic","ne","ea",
    ]

    private func latinDelay(_ i: Int) -> Double {
        let cur = u[i]
        let prev = i > 0 ? u[i - 1] : ""
        var f = flow
        let c = cur.first ?? " "

        if c.isUppercase || "~!@#$%^&*()_+{}|:\"<>?".contains(c) { f *= 1.35 }
        else if c.isNumber { f *= 1.15 }
        else if c.isPunctuation || c.isSymbol { f *= 1.2 }

        if prev == " " { f *= 1.12 }
        if prev.count == 1 && TypingEngine.fastBigrams.contains((prev + cur).lowercased()) { f *= 0.75 }
        if prev == cur { f *= 0.85 }
        if cur == " " { f *= 0.9 }

        return clamp(latinBaseMs * f * jitter(), 18, latinBaseMs * 6)
    }

    private func jitter() -> Double {
        let sigma = Double(s.variance) / 100 * 0.6
        return exp(sigma * gaussian())
    }

    private func driftFlow() {
        let v = Double(s.variance) / 100
        flow *= exp(gaussian() * 0.12 * v)
        flow += (1.0 - flow) * 0.15   // pull back towards normal pace
        flow = clamp(flow, 0.75, 1.35)
    }

    private func pickChunkLength(_ maxLen: Int) -> Int {
        let r = Double.random(in: 0..<1)
        let len = r < 0.25 ? 1 : r < 0.80 ? 2 : r < 0.95 ? 3 : 4
        return max(1, min(len, maxLen))
    }

    // ------------------------------------------------------------------ Chinese (IME-like)

    private func typeCjkChunk(_ start: Int, _ len: Int) throws {
        // Time spent "spelling pinyin" for the whole word, then the word is committed in a burst.
        try wait(Double(len) * cjkBaseMs * 0.85 * flow * jitter())

        let p = 1 - pow(1 - s.typoRate / 100, Double(len))
        if chance(p) {
            // Picked the wrong IME candidate: type wrong characters, notice, delete, re-pick.
            let bad = Int.random(in: 0..<len)
            let whole = chance(0.5)
            var wrong: [String] = []
            for k in 0..<len { wrong.append(whole || k == bad ? randomCommonHan(u[start + k]) : u[start + k]) }
            for k in 0..<len {
                try key(wrong[k])
                if k + 1 < len { try wait(rand(12, 40)) }
            }
            try wait(rand(300, 1000))                         // notice it
            for _ in 0..<len { try key("\u{8}"); try wait(rand(70, 160)) }
            try wait(rand(250, 700))                          // re-pick the right candidate
        } else {
            try wait(rand(40, 160))                           // choosing candidate / pressing space
        }

        for k in 0..<len {
            try key(u[start + k])
            if k + 1 < len { try wait(rand(12, 40)) }
        }
    }

    private static let commonHan = Array(
        "的一是在不了有和人这中大为上个国我以要他时来用们生到作地于出就分对成会可主发年动同工也能下过子说产种面而方后多定行学法所民得经十三之进着等部度家电力里如水化高自二理起小物现实加量都两体制机当使点从业本去把性好应开它合还因由其些然前外天政四日那社义事平形相全表间样与关各重新线内数正心反你明看原又么利比或但质气第向道命此变条只没结解问意建月公无系军很情者最立代想已通并提直题程展五果料象员革位入常文总次品式活设及管特件长求老头基资边流路级少图山统接知较将组见计别她手角期根论运农指几九区强放决西被干做必战先回则任取据处府研")

    private func randomCommonHan(_ avoid: String) -> String {
        for _ in 0..<5 {
            let c = String(TypingEngine.commonHan.randomElement()!)
            if c != avoid { return c }
        }
        return "的"
    }

    // ------------------------------------------------------------------ Latin typos

    private static let neighbors: [Character: String] = [
        "q":"wa","w":"qeas","e":"wrsd","r":"etdf","t":"ryfg","y":"tugh","u":"yihj",
        "i":"uojk","o":"ipkl","p":"ol","a":"qwsz","s":"awedxz","d":"serfcx","f":"drtgvc",
        "g":"ftyhbv","h":"gyujnb","j":"huikmn","k":"jiolm","l":"kop","z":"asx","x":"zsdc",
        "c":"xdfv","v":"cfgb","b":"vghn","n":"bhjm","m":"njk",
        "1":"2q","2":"13w","3":"24e","4":"35r","5":"46t","6":"57y","7":"68u","8":"79i","9":"80o","0":"9p",
    ]

    private static func isTypoCandidate(_ u: String) -> Bool {
        guard u.count == 1, let c = u.first, c.isASCII else { return false }
        return c.isLetter || c.isNumber
    }

    private static func isLatinLetter(_ u: String?) -> Bool {
        guard let u, u.count == 1, let c = u.first else { return false }
        return c.isASCII && c.isLetter
    }

    /// Types a mistake starting at i, then fixes it. Returns the index to continue from, or -1.
    private func doLatinTypo(_ i: Int) throws -> Int {
        let cur = u[i]
        let next: String? = i + 1 < u.count ? u[i + 1] : nil
        var typed: [String] = []
        var follow: Int

        let r = Double.random(in: 0..<1)
        if r < 0.15 && TypingEngine.isLatinLetter(next) && next != cur {
            typed += [next!, cur]                       // transposition: "teh"
            follow = i + 2
        } else if r < 0.30 {
            typed += [cur, cur]                         // doubled key
            follow = i + 1
        } else if r < 0.42 && TypingEngine.isLatinLetter(next) {
            typed.append(next!)                         // skipped a key
            follow = i + 2
        } else {
            let first = cur.first!
            let lc = Character(first.lowercased())
            guard let nb = TypingEngine.neighbors[lc], let w = nb.randomElement() else { return -1 }
            typed.append(first.isUppercase ? w.uppercased() : String(w))   // fat-fingered neighbour key
            follow = i + 1
        }

        // Keep typing a few more characters before noticing (never across a line break).
        let extra = pickNoticeDelay()
        var k = 0
        while k < extra && follow + k < u.count {
            let x = u[follow + k]
            if x == "\n" || TypingEngine.isCjk(x) { break }
            typed.append(x)
            k += 1
        }

        // How much of what we typed is accidentally correct?
        var prefix = 0
        while prefix < typed.count && i + prefix < u.count && typed[prefix] == u[i + prefix] { prefix += 1 }
        if prefix == typed.count { return -1 }          // not actually a mistake

        for (k, t) in typed.enumerated() {
            try wait(latinDelay(min(i + k, u.count - 1)))
            try key(t)
        }

        try wait(rand(250, 750) * (0.8 + 0.4 * Double.random(in: 0..<1)))   // "wait, that's wrong"
        for _ in 0..<(typed.count - prefix) {
            try key("\u{8}")
            try wait(max(45, latinBaseMs * 0.6 * jitter()))
        }
        try wait(rand(100, 300))
        return i + prefix
    }

    private func pickNoticeDelay() -> Int {
        let m = max(0, s.maxNoticeDelay)
        if m == 0 { return 0 }
        let r = Double.random(in: 0..<1)
        let k = r < 0.5 ? 0 : r < 0.75 ? 1 : r < 0.9 ? 2 : 3
        return min(k, m)
    }

    // ------------------------------------------------------------------ thinking pauses

    private func afterUnit(_ idx: Int) throws {
        let unit = u[idx]
        let prev: String? = idx > 0 ? u[idx - 1] : nil
        guard idx + 1 < u.count else { return }
        let next = u[idx + 1]

        if unit == "\n" {
            pendingSentence = false
            if prev == "\n" { try wait(rand(150, 400)); return }
            if next == "\n" { return }   // pause after the last of several line breaks
            if s.thinkEnabled {
                try think(rand(s.paraPauseMin, s.paraPauseMax) * 1000, "构思下一段")
                resetWordCounter()
                resetSentenceCounter()
            } else {
                try wait(rand(200, 600))
            }
            return
        }

        if isSentenceEnd(idx) { pendingSentence = true }
        else if s.punctPause && TypingEngine.isClausePunct(unit) { try wait(rand(80, 350)) }

        if unit == " " && prev != " " && !TypingEngine.isCjk(prev ?? "") { try afterWord(idx) }

        if pendingSentence && next != " " {
            pendingSentence = false
            try wait(rand(150, 500))
            if s.thinkEnabled {
                sentencesLeft -= 1
                if sentencesLeft <= 0 {
                    try think(rand(s.sentPauseMin, s.sentPauseMax) * 1000, "思考下一句")
                    resetSentenceCounter()
                    resetWordCounter()
                }
            }
        }
    }

    private func afterWord(_ idx: Int) throws {
        driftFlow()
        guard s.thinkEnabled else { return }
        wordsLeft -= 1
        if wordsLeft > 0 { return }
        resetWordCounter()
        if idx + 1 >= u.count { return }
        try think(rand(s.wordPauseMin, s.wordPauseMax) * 1000, "停顿")
    }

    private func resetWordCounter() {
        wordsLeft = Int.random(in: s.wordEveryMin...max(s.wordEveryMin, s.wordEveryMax))
    }

    private func resetSentenceCounter() {
        sentencesLeft = Int.random(in: s.sentEveryMin...max(s.sentEveryMin, s.sentEveryMax))
    }

    private func think(_ ms: Double, _ what: String) throws {
        if ms <= 0 { return }
        report(.thinking, String(format: "%@…（%.1f 秒）", what, ms / 1000))
        try wait(ms)
        report(.running, "正在输入…")
    }

    private func isSentenceEnd(_ idx: Int) -> Bool {
        let unit = u[idx]
        let next: String? = idx + 1 < u.count ? u[idx + 1] : nil
        if TypingEngine.isClosing(unit) {
            guard idx > 0 else { return false }
            return TypingEngine.isEndPunct(u[idx - 1], loose: true) && (next == nil || !TypingEngine.isClosing(next!))
        }
        if !TypingEngine.isEndPunct(unit, loose: false) { return false }
        guard let next else { return true }
        if TypingEngine.isClosing(next) || TypingEngine.isEndPunct(next, loose: true) { return false }
        if unit == "." { return next == " " || next == "\n" || TypingEngine.isCjk(next) }
        return true
    }

    private static func isEndPunct(_ u: String, loose: Bool) -> Bool {
        ["。", "！", "？", "!", "?", "…", "."].contains(u) || (loose && u == "；")
    }

    private static func isClosing(_ u: String) -> Bool {
        ["”", "’", "」", "』", "）", ")", "\"", "'", "》"].contains(u)
    }

    private static func isClausePunct(_ u: String) -> Bool {
        [",", ";", ":", "，", "；", "：", "、"].contains(u)
    }

    // ------------------------------------------------------------------ gating / pause handling

    private var startKeyName: String { s.startPauseKey.displayName }

    /// Sleeps for ms while honouring pause/stop and sampling the caret.
    private func wait(_ ms: Double) throws {
        var end = now + Int64(ms)
        while true {
            end += try gate()
            let t = now
            if t >= end { return }
            sampleCaret()
            usleep(UInt32(min(20, end - t)) * 1000)
        }
    }

    /// Blocks while paused. Returns the time spent blocked (ms).
    @discardableResult
    private func gate() throws -> Int64 {
        let t0 = now
        var wasPaused = false, wasManual = false
        var okStreak = 0
        var lastMsg: String?

        while true {
            if stopFlag { throw Cancelled() }

            if rebaseline {
                rebaseline = false
                doRebaseline()
                autoPaused = false
                if wasPaused { break }
            }

            if manualPause {
                wasPaused = true; wasManual = true
                say(&lastMsg, .paused, "已暂停 — 按 \(startKeyName) 或点“继续”恢复")
                usleep(40_000)
                continue
            }

            if s.autoPause, let reason = checkTarget() {
                autoPaused = true; wasPaused = true; okStreak = 0
                say(&lastMsg, .paused, reason)
                usleep(60_000)
                continue
            }

            if wasPaused && !wasManual {
                okStreak += 1
                if okStreak < 4 { usleep(80_000); continue }   // make sure the user really is back
            }
            break
        }

        if wasPaused {
            autoPaused = false
            report(.running, "继续输入…")
            try sleepPlain(rand(500, 1300))   // re-orient before typing again
            doCatchUp()
            lastSampleMs = 0
        }
        return now - t0
    }

    private func say(_ last: inout String?, _ st: EngineState, _ msg: String) {
        if msg == last { return }
        last = msg
        report(st, msg)
    }

    private func checkTarget() -> String? {
        let fg = CaretProbe.frontPid()
        if fg != target {
            return "目标程序不在前台（当前前台：\(CaretProbe.appName(fg))）— 切回原输入位置后自动继续，或按 \(startKeyName) 在当前位置继续"
        }

        let snap = CaretProbe.read()
        if targetFocus != nil && snap.focus != nil && !snap.sameFocus(CaretSnapshot(focus: targetFocus)) {
            if !interfered {
                // the program moved focus by itself (no click / key from the user): follow it
                targetFocus = snap.focus; baseline = snap; unsampled = 0; caretTracks = false
            } else {
                return "输入焦点离开了原输入框 — 点回原处后自动继续，或按 \(startKeyName) 在当前位置继续"
            }
        }

        if interfered {
            if now - lastUserInputMs < 450 { return "检测到手动操作，已暂停…" }
            if !baseline.caretOk || !snap.caretOk || !caretTracks {
                return "检测到手动操作，已暂停 — 读不到光标位置，把光标放回原处后按 \(startKeyName) 继续"
            }
            if snap.loc != baseline.loc {
                // The last few keystrokes may not have been sampled yet: accept a caret that sits
                // just after the remembered spot (= the real end).
                let ahead = snap.loc - baseline.loc
                if unsampled > 0 && ahead > 0 && ahead <= unsampled {
                    catchUp = unsampled - ahead
                    baseline = snap
                    interfered = false
                    return nil
                }
                return "光标已离开原位置 — 把光标点回原处后自动继续"
            }
            // Back where we last saw it; keystrokes sent after that sample are further right.
            catchUp = unsampled
            interfered = false
        }
        return nil
    }

    /// Moves the caret over characters we typed after the last caret sample.
    private func doCatchUp() {
        let n = catchUp
        catchUp = 0
        if n == 0 { return }
        for _ in 0..<abs(n) {
            if n > 0 { kb.right() } else { kb.left() }
            usleep(UInt32.random(in: 30_000...70_000))
        }
        unsampled = 0
        lastKeyMs = now
    }

    private func doRebaseline() {
        let fg = CaretProbe.frontPid()
        guard fg != 0 && fg != ownPid else { return }
        target = fg
        let snap = CaretProbe.read()
        targetFocus = snap.focus
        baseline = snap
        unsampled = 0
        catchUp = 0
        interfered = false
    }

    /// Remembers where the caret is while nobody is touching anything.
    private func sampleCaret() {
        let t = now
        if interfered || t - lastKeyMs < 25 { return }
        if unsampled == 0 && t - lastSampleMs < 150 { return }
        lastSampleMs = t
        guard CaretProbe.frontPid() == target else { return }
        let snap = CaretProbe.read()
        if interfered || CaretProbe.frontPid() != target { return }
        if targetFocus == nil { targetFocus = snap.focus }
        if snap.focus == nil || snap.sameFocus(CaretSnapshot(focus: targetFocus)) {
            baseline = snap
            unsampled = 0
        }
    }

    private func sleepPlain(_ ms: Double) throws {
        let end = now + Int64(ms)
        while now < end {
            if stopFlag { throw Cancelled() }
            usleep(20_000)
        }
    }

    // ------------------------------------------------------------------ keyboard output

    private func key(_ unit: String) throws {
        try gate()
        sampleCaret()
        if interfered { try gate() }
        switch unit {
        case "\n": kb.enter(shift: s.newlineMode == 1)
        case "\t": kb.tab()
        case "\u{8}": kb.backspace()
        case " ": kb.space()
        default: kb.char(unit)
        }
        lastKeyMs = now
        unsampled += unit == "\u{8}" ? -1 : 1
        settleSample()
    }

    /// Right after a keystroke, waits (max ~40 ms) until the target has moved its caret and remembers
    /// the new position, so the "original position" is never a character behind.
    private func settleSample() {
        let before = baseline
        if !before.caretOk || interfered { return }
        let until = now + 40
        while now < until {
            usleep(8_000)
            if interfered || CaretProbe.frontPid() != target { return }
            let snap = CaretProbe.read()
            if interfered || !snap.caretOk { return }
            if snap.loc != before.loc || !snap.sameFocus(before) {
                if snap.sameFocus(CaretSnapshot(focus: targetFocus)) {
                    caretTracks = true      // the caret follows our typing: it's the real one
                    baseline = snap
                    unsampled = 0
                    lastSampleMs = now
                }
                return
            }
        }
    }

    // ------------------------------------------------------------------ proofreading

    /// Reads the typed text back through the Accessibility API and fixes differences with the keyboard:
    /// arrow keys to the wrong spot, Backspace, retype. Only touches the part typed in this run.
    private func proofread() throws {
        guard let focus = startFocus, startLoc >= 0, CaretProbe.text(of: focus) != nil else {
            proofMsg = "读不到目标文本，已跳过核对"
            return
        }
        report(.proofreading, "核对中…")
        fixing = true
        defer { fixing = false }
        let expected = Array(TypingEngine.normalize(u.joined()))
        var fixes = 0

        for _ in 0..<3 {
            try wait(rand(500, 1100))   // read it over
            guard CaretProbe.frontPid() == target else { proofMsg = "目标程序不在前台，已跳过核对"; return }
            let snap = CaretProbe.read()
            guard snap.sameFocus(CaretSnapshot(focus: focus)), snap.loc >= startLoc,
                  let value = CaretProbe.text(of: focus)
            else { proofMsg = "输入框已变化，已跳过核对"; return }
            let ns = value as NSString
            guard snap.loc <= ns.length else { proofMsg = "读不到目标文本，已跳过核对"; return }
            let actual = Array(TypingEngine.normalize(ns.substring(with: NSRange(location: startLoc, length: snap.loc - startLoc))))
            if actual == expected {
                proofMsg = fixes > 0 ? "已修正 \(fixes) 处" : "核对无误"
                return
            }

            var p = 0
            while p < actual.count && p < expected.count && actual[p] == expected[p] { p += 1 }
            var sfx = 0
            while sfx < actual.count - p && sfx < expected.count - p &&
                  actual[actual.count - 1 - sfx] == expected[expected.count - 1 - sfx] { sfx += 1 }
            let del = actual.count - p - sfx
            let ins = expected[p..<(expected.count - sfx)]
            if del + ins.count > max(40, expected.count / 2) {
                proofMsg = "差异过大（光标可能被移动过），已放弃修正"
                return
            }

            report(.proofreading, "核对中 — 正在修正…")
            for _ in 0..<sfx { try gate(); kb.left(); try sleepPlain(rand(30, 70)) }
            for _ in 0..<del { try key("\u{8}"); try wait(rand(50, 120)) }
            for c in ins { try key(String(c)); try wait(rand(60, 160)) }
            for _ in 0..<sfx { try gate(); kb.right(); try sleepPlain(rand(30, 70)) }
            fixes += 1
        }
        proofMsg = "已修正 \(fixes) 处，仍有差异"
    }

    // ------------------------------------------------------------------ helpers

    static func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }

    /// Splits text into visible characters (grapheme clusters), line breaks normalised to "\n".
    static func split(_ text: String) -> [String] {
        normalize(text).map { String($0) }
    }

    static func isCjk(_ u: String) -> Bool {
        guard let v = u.unicodeScalars.first?.value else { return false }
        return (0x4E00...0x9FFF).contains(v) || (0x3400...0x4DBF).contains(v) || (0xF900...0xFAFF).contains(v)
            || (0x3040...0x30FF).contains(v) || (0xAC00...0xD7AF).contains(v) || (0x20000...0x3FFFF).contains(v)
    }

    private func chance(_ p: Double) -> Bool { Double.random(in: 0..<1) < p }

    private func rand(_ a: Double, _ b: Double) -> Double {
        let lo = min(a, b), hi = max(a, b)
        return lo + Double.random(in: 0..<1) * (hi - lo)
    }

    private func gaussian() -> Double {
        let u1 = 1.0 - Double.random(in: 0..<1), u2 = Double.random(in: 0..<1)
        return sqrt(-2.0 * log(u1)) * cos(2 * Double.pi * u2)
    }

    private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { v < lo ? lo : v > hi ? hi : v }

    private func report(_ st: EngineState, _ msg: String) { onState?(myRun, st, msg) }

    private func progress(_ done: Int, force: Bool) {
        let t = now
        if !force && t - lastProgressMs < 60 { return }
        lastProgressMs = t
        onProgress?(myRun, done, u.count)
    }

    /// Rough duration estimate in seconds.
    static func estimate(_ text: String, _ s: Settings) -> Double {
        let u = split(text)
        var cjk = 0, latin = 0, words = 0, sentences = 0, paras = 0
        for (i, x) in u.enumerated() {
            if isCjk(x) { cjk += 1 }
            else {
                latin += 1
                if x == " " && i > 0 && u[i - 1] != " " { words += 1 }
                if x == "\n" && i > 0 && u[i - 1] != "\n" { paras += 1 }
            }
            if ["。", "！", "？", ".", "!", "?"].contains(x) { sentences += 1 }
        }
        words += cjk / 2
        var sec = Double(latin) * 12.0 / Double(max(5, s.enWpm)) + Double(cjk) * 60.0 / Double(max(5, s.zhCpm))
        sec *= 1 + s.typoRate / 100 * 4
        sec += Double(sentences) * 0.35
        if s.thinkEnabled {
            sec += Double(words) / max(1.0, Double(s.wordEveryMin + s.wordEveryMax) / 2) * (s.wordPauseMin + s.wordPauseMax) / 2
            sec += Double(sentences) / max(1.0, Double(s.sentEveryMin + s.sentEveryMax) / 2) * (s.sentPauseMin + s.sentPauseMax) / 2
            sec += Double(paras) * (s.paraPauseMin + s.paraPauseMax) / 2
        }
        return sec
    }
}

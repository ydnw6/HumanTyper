import Foundation

/// Chinese → toneless pinyin (ü written as v, as typed on a keyboard). Same table as the Windows version
/// (src/Resources/pinyin.dat.gz, from mozillazg/pinyin-data, MIT); build-app.sh unpacks it into the app's
/// Resources as pinyin.dat. Multi-character phrases are matched longest-first so polyphones get the
/// reading that fits the word (银行 → yin hang, 睡觉 → shui jiao).
enum Pinyin {
    private static let map: [String: [String]] = {
        var d: [String: [String]] = [:]
        guard let text = loadTable() else { return d }
        d.reserveCapacity(32000)
        text.enumerateLines { line, _ in
            guard let tab = line.firstIndex(of: "\t"), tab != line.startIndex else { return }
            d[String(line[..<tab])] = line[line.index(after: tab)...].split(separator: " ").map(String.init)
        }
        return d
    }()

    private static func loadTable() -> String? {
        var candidates: [URL] = []
        if let u = Bundle.main.url(forResource: "pinyin", withExtension: "dat") { candidates.append(u) }
        // `swift run` during development: an unpacked copy next to the executable
        let exeDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        candidates.append(exeDir.appendingPathComponent("pinyin.dat"))
        for u in candidates {
            if let data = try? Data(contentsOf: u), let s = String(data: data, encoding: .utf8) { return s }
        }
        return nil
    }

    static var isLoaded: Bool { !map.isEmpty }

    /// One syllable per unit, or nil for units with no known reading.
    static func of(_ units: [String], _ start: Int, _ count: Int) -> [String?] {
        var result = [String?](repeating: nil, count: count)
        var i = 0
        while i < count {
            var matched = false
            var len = min(4, count - i)
            while len >= 2 {
                let word = units[(start + i)..<(start + i + len)].joined()
                if let syl = map[word], syl.count == len {
                    for k in 0..<len { result[i + k] = syl[k] }
                    i += len
                    matched = true
                    break
                }
                len -= 1
            }
            if matched { continue }
            result[i] = map[units[start + i]]?.first
            i += 1
        }
        return result
    }

    /// Joins syllables the way people type them, with an apostrophe where the next syllable starts with
    /// a vowel and could otherwise merge (xi'an, fang'an).
    static func join(_ syllables: [String]) -> String {
        var s = ""
        for syl in syllables where !syl.isEmpty {
            if !s.isEmpty, let c = syl.first, "aeo".contains(c) { s += "'" }
            s += syl
        }
        return s
    }
}

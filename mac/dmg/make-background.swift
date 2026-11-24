// Draws the background of the HumanTyper.dmg window (660 × 420 pt): composition paper, a title, an arrow
// from the app icon to the Applications shortcut, and first-launch tips along the bottom.
// Icon centres used by dmg-settings.py: app (170, 200), Applications (490, 200) — top-left origin.
// Run from the repo root:  swift mac/dmg/make-background.swift   → mac/dmg/background.png
import AppKit

let W: CGFloat = 660, H: CGFloat = 420
let paper = NSColor(srgbRed: 0.969, green: 0.973, blue: 0.953, alpha: 1)   // #F7F8F3
let grid = NSColor(srgbRed: 0.180, green: 0.490, blue: 0.357, alpha: 1)    // #2E7D5B
let ink = NSColor(srgbRed: 0.102, green: 0.141, blue: 0.125, alpha: 1)     // #1A2420
let muted = NSColor(srgbRed: 0.373, green: 0.420, blue: 0.392, alpha: 1)   // #5F6B64
let red = NSColor(srgbRed: 0.824, green: 0.216, blue: 0.169, alpha: 1)     // #D2372B

func kai(_ size: CGFloat) -> NSFont { NSFont(name: "STKaiti", size: size) ?? .systemFont(ofSize: size, weight: .medium) }
func sans(_ size: CGFloat, _ w: NSFont.Weight = .regular) -> NSFont {
    NSFont(name: w == .regular ? "PingFangSC-Regular" : "PingFangSC-Medium", size: size) ?? .systemFont(ofSize: size, weight: w)
}

/// Draws text centred on x, with its baseline-box top at `top` (top-left coordinates).
func text(_ s: String, _ font: NSFont, _ color: NSColor, x: CGFloat, top: CGFloat) {
    let a = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color])
    let sz = a.size()
    a.draw(at: NSPoint(x: x - sz.width / 2, y: H - top - sz.height))
}

func render(scale: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W * scale), pixelsHigh: Int(H * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)   // 72 dpi at 1x, 144 dpi at 2x
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current!.cgContext.scaleBy(x: scale, y: scale)

    paper.setFill()
    NSRect(x: 0, y: 0, width: W, height: H).fill()

    // ruled lines + a red margin line, like an exercise book
    grid.withAlphaComponent(0.10).setFill()
    var y: CGFloat = 28
    while y < H { NSRect(x: 0, y: y, width: W, height: 1).fill(); y += 28 }
    red.withAlphaComponent(0.25).setFill()
    NSRect(x: 44, y: 0, width: 1, height: H).fill()

    text("把 HumanTyper 拖进“应用程序”", kai(26), ink, x: W / 2, top: 34)
    text("拖完就装好了，可以推出这个磁盘", sans(13), muted, x: W / 2, top: 76)

    // soft cells behind the two icons
    for cx in [CGFloat(170), 490] {
        let r = NSRect(x: cx - 78, y: H - 200 - 78, width: 156, height: 156)
        NSColor.white.withAlphaComponent(0.7).setFill()
        NSBezierPath(rect: r).fill()
        let b = NSBezierPath(rect: r)
        b.lineWidth = 1.5
        b.setLineDash([6, 5], count: 2, phase: 0)
        grid.withAlphaComponent(0.45).setStroke()
        b.stroke()
    }

    // arrow between them
    let ay = H - 192
    let shaft = NSBezierPath()
    shaft.lineWidth = 4
    shaft.lineCapStyle = .round
    shaft.setLineDash([10, 9], count: 2, phase: 0)
    shaft.move(to: NSPoint(x: 268, y: ay)); shaft.line(to: NSPoint(x: 384, y: ay))
    grid.setStroke()
    shaft.stroke()
    let head = NSBezierPath()
    head.lineWidth = 4
    head.lineCapStyle = .round
    head.lineJoinStyle = .round
    head.move(to: NSPoint(x: 376, y: ay + 12)); head.line(to: NSPoint(x: 392, y: ay)); head.line(to: NSPoint(x: 376, y: ay - 12))
    head.stroke()

    // first-launch tips
    NSColor.white.withAlphaComponent(0.6).setFill()
    NSRect(x: 0, y: 0, width: W, height: 96).fill()
    grid.withAlphaComponent(0.35).setFill()
    NSRect(x: 0, y: 96, width: W, height: 1).fill()
    text("第一次打开提示“无法验证开发者”：系统设置 → 隐私与安全性 → 点“仍要打开”", sans(12.5), ink, x: W / 2, top: H - 84)
    text("然后在“隐私与安全性 → 辅助功能”里打开 HumanTyper 的开关，才能模拟键盘输入", sans(12.5), ink, x: W / 2, top: H - 62)
    text("本软件永久免费开源 · github.com/ydnw6/HumanTyper", sans(11), muted, x: W / 2, top: H - 36)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

// A plain 72-dpi PNG at exactly the window size. Finder in current macOS draws the background at its pixel
// size and ignores DPI, so a Retina (2x) image or a multi-resolution TIFF would show up at double size.
let out = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("mac/dmg/background.png")
try render(scale: 1).representation(using: .png, properties: [:])!.write(to: out)
print("wrote", out.path)

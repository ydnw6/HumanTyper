// Draws the HumanTyper app icon: the character 打 written in a composition-paper cell (田字格),
// with the red stroke from the site's logo standing in as a text caret.
// Run on a Mac from the repo root:   swift assets/icon/make-icon.swift
// Writes assets/icon/icon-mac-1024.png, assets/icon/icon-win-256.png, mac/AppIcon.icns and HumanTyper.ico.
import AppKit

let paperTop = NSColor(srgbRed: 0.992, green: 0.992, blue: 0.984, alpha: 1)   // #FDFDFB
let paperBottom = NSColor(srgbRed: 0.937, green: 0.949, blue: 0.918, alpha: 1)  // #EFF2EA
let grid = NSColor(srgbRed: 0.180, green: 0.490, blue: 0.357, alpha: 1)       // #2E7D5B
let ink = NSColor(srgbRed: 0.102, green: 0.141, blue: 0.125, alpha: 1)        // #1A2420
let red = NSColor(srgbRed: 0.824, green: 0.216, blue: 0.169, alpha: 1)        // #D2372B

/// mac: Big Sur icon grid (824 pt body on a 1024 canvas, soft drop shadow).  win: fills the canvas.
func render(px: Int, mac: Bool) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let s = CGFloat(px) / 1024
    ctx.scaleBy(x: s, y: s)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    let body = mac ? NSRect(x: 100, y: 100, width: 824, height: 824) : NSRect(x: 16, y: 16, width: 992, height: 992)
    let radius: CGFloat = mac ? 185 : 200
    let shape = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)

    // shadow + paper
    NSGraphicsContext.saveGraphicsState()
    if mac {
        let sh = NSShadow()
        sh.shadowColor = NSColor.black.withAlphaComponent(0.28)
        sh.shadowBlurRadius = 28
        sh.shadowOffset = NSSize(width: 0, height: -12)
        sh.set()
    }
    paperBottom.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: paperTop, ending: paperBottom)!.draw(in: shape, angle: -90)

    // faint ruled lines across the sheet, like the page the cell sits on
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    grid.withAlphaComponent(0.10).setStroke()
    let rule = NSBezierPath()
    rule.lineWidth = 4
    var y = body.minY + body.height * 0.13
    while y < body.maxY {
        rule.move(to: NSPoint(x: body.minX, y: y)); rule.line(to: NSPoint(x: body.maxX, y: y))
        y += body.height * 0.185
    }
    rule.stroke()
    NSGraphicsContext.restoreGraphicsState()

    // the 田字格 cell
    let cellSize = body.width * 0.66
    let cell = NSRect(x: body.midX - cellSize / 2 - body.width * 0.035, y: body.midY - cellSize / 2,
                      width: cellSize, height: cellSize)
    NSColor.white.withAlphaComponent(0.75).setFill()
    NSBezierPath(rect: cell).fill()
    let guide = NSBezierPath()
    guide.lineWidth = 6
    guide.setLineDash([22, 16], count: 2, phase: 0)
    guide.move(to: NSPoint(x: cell.midX, y: cell.minY)); guide.line(to: NSPoint(x: cell.midX, y: cell.maxY))
    guide.move(to: NSPoint(x: cell.minX, y: cell.midY)); guide.line(to: NSPoint(x: cell.maxX, y: cell.midY))
    grid.withAlphaComponent(0.45).setStroke()
    guide.stroke()
    let frame = NSBezierPath(rect: cell)
    frame.lineWidth = 16
    grid.setStroke()
    frame.stroke()

    // 打, in a Kai (brush-style) face
    let font = NSFont(name: "STKaiti", size: cellSize * 0.84) ?? NSFont(name: "Kaiti SC", size: cellSize * 0.84)
        ?? NSFont.systemFont(ofSize: cellSize * 0.8, weight: .bold)
    let glyph = NSAttributedString(string: "打", attributes: [.font: font, .foregroundColor: ink])
    let line = CTLineCreateWithAttributedString(glyph)
    let gb = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    ctx.saveGState()
    ctx.textPosition = CGPoint(x: cell.midX - gb.midX, y: cell.midY - gb.midY)
    CTLineDraw(line, ctx)
    ctx.restoreGState()

    // red caret just after the cell: "still typing"
    let caretW: CGFloat = 30
    let caret = NSRect(x: cell.maxX + body.width * 0.05, y: cell.minY + cellSize * 0.10,
                       width: caretW, height: cellSize * 0.80)
    red.setFill()
    NSBezierPath(roundedRect: caret, xRadius: caretW / 2, yRadius: caretW / 2).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func png(_ rep: NSBitmapImageRep) -> Data { rep.representation(using: .png, properties: [:])! }

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconDir = root.appendingPathComponent("assets/icon")
try png(render(px: 1024, mac: true)).write(to: iconDir.appendingPathComponent("icon-mac-1024.png"))
try png(render(px: 256, mac: false)).write(to: iconDir.appendingPathComponent("icon-win-256.png"))

// macOS .icns via iconutil
let set = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon-\(getpid()).iconset")
try? FileManager.default.removeItem(at: set)
try FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try png(render(px: base, mac: true)).write(to: set.appendingPathComponent("icon_\(base)x\(base).png"))
    try png(render(px: base * 2, mac: true)).write(to: set.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", set.path, "-o", root.appendingPathComponent("mac/AppIcon.icns").path]
try p.run(); p.waitUntilExit()
try? FileManager.default.removeItem(at: set)

// Windows .ico: PNG-compressed entries (supported since Vista)
let sizes = [16, 20, 24, 32, 40, 48, 64, 128, 256]
let images = sizes.map { png(render(px: $0, mac: false)) }
var ico = Data()
func le16(_ v: Int) { ico.append(contentsOf: [UInt8(v & 0xff), UInt8(v >> 8 & 0xff)]) }
func le32(_ v: Int) { le16(v & 0xffff); le16(v >> 16 & 0xffff) }
le16(0); le16(1); le16(sizes.count)
var offset = 6 + 16 * sizes.count
for (sz, img) in zip(sizes, images) {
    ico.append(UInt8(sz >= 256 ? 0 : sz)); ico.append(UInt8(sz >= 256 ? 0 : sz))
    ico.append(0); ico.append(0)
    le16(1); le16(32); le32(img.count); le32(offset)
    offset += img.count
}
for img in images { ico.append(img) }
try ico.write(to: root.appendingPathComponent("HumanTyper.ico"))
print("icons written")

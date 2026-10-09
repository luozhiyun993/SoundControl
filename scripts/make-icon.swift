// 生成 App 图标：圆角方形底 + 三条高低不同的竖向滑块，表示"每个应用一条音量"。
// 用法：swift scripts/make-icon.swift <输出 1024px PNG 路径>
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

// 直接画到 1024×1024 像素的位图上，避免 Retina 屏下被放大成 2048。
let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
let context = NSGraphicsContext(bitmapImageRep: bitmap)!.cgContext

// macOS 图标网格：内容区 824×824，四周留白 100。
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil)

// 投影
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.28).cgColor)
context.addPath(tilePath)
context.setFillColor(NSColor.black.cgColor)
context.fillPath()
context.restoreGState()

// 底色渐变
context.saveGState()
context.addPath(tilePath)
context.clip()
let colors = [
    NSColor(srgbRed: 0.42, green: 0.40, blue: 0.98, alpha: 1).cgColor,
    NSColor(srgbRed: 0.18, green: 0.14, blue: 0.62, alpha: 1).cgColor,
] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])

// 顶部高光
let highlight = [NSColor.white.withAlphaComponent(0.18).cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray
let highlightGradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: highlight, locations: [0, 1])!
context.drawLinearGradient(highlightGradient, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.midY), options: [])

// 三条滑块
let trackWidth: CGFloat = 44
let trackTop = tile.maxY - 190
let trackBottom = tile.minY + 190
let knobRadius: CGFloat = 56
let levels: [CGFloat] = [0.60, 0.28, 0.80]
let xs: [CGFloat] = [tile.midX - 220, tile.midX, tile.midX + 220]

for (x, level) in zip(xs, levels) {
    let track = CGRect(x: x - trackWidth / 2, y: trackBottom, width: trackWidth, height: trackTop - trackBottom)
    context.addPath(CGPath(roundedRect: track, cornerWidth: trackWidth / 2, cornerHeight: trackWidth / 2, transform: nil))
    context.setFillColor(NSColor.white.withAlphaComponent(0.22).cgColor)
    context.fillPath()

    let knobY = trackBottom + (trackTop - trackBottom) * level
    let fill = CGRect(x: track.minX, y: trackBottom, width: trackWidth, height: knobY - trackBottom)
    context.addPath(CGPath(roundedRect: fill, cornerWidth: trackWidth / 2, cornerHeight: trackWidth / 2, transform: nil))
    context.setFillColor(NSColor.white.withAlphaComponent(0.92).cgColor)
    context.fillPath()

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: NSColor.black.withAlphaComponent(0.30).cgColor)
    context.addEllipse(in: CGRect(x: x - knobRadius, y: knobY - knobRadius, width: knobRadius * 2, height: knobRadius * 2))
    context.setFillColor(NSColor.white.cgColor)
    context.fillPath()
    context.restoreGState()
}
context.restoreGState()

try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))

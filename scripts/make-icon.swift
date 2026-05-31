import AppKit

// 从 logo PNG 合成 macOS 风格图标：白色圆角方底板 + logo 居中。
// 用法：swift make-icon.swift <logo.png> <输出 1024 png>
let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("用法: swift make-icon.swift <logo.png> <out.png>\n".data(using: .utf8)!)
    exit(1)
}
let logoPath = args[1]
let outPath = args[2]
let canvas = 1024

guard let logo = NSImage(contentsOfFile: logoPath) else {
    FileHandle.standardError.write("错误: 无法读取 \(logoPath)\n".data(using: .utf8)!)
    exit(1)
}

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: canvas, pixelsHigh: canvas,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
ctx.interpolationQuality = .high

ctx.clear(CGRect(x: 0, y: 0, width: canvas, height: canvas))

// 底板：留 100px 透明 margin（符合 macOS 现代图标，系统不再二次裁切）
let inset: CGFloat = 100
let plate = CGRect(x: inset, y: inset, width: CGFloat(canvas) - 2 * inset, height: CGFloat(canvas) - 2 * inset)
let radius = plate.width * 0.2237  // squircle 近似圆角
ctx.addPath(CGPath(roundedRect: plate, cornerWidth: radius, cornerHeight: radius, transform: nil))
ctx.setFillColor(NSColor.white.cgColor)
ctx.fillPath()

// logo 居中，占底板 55%
let logoSize = plate.width * 0.55
let logoRect = CGRect(x: plate.midX - logoSize / 2, y: plate.midY - logoSize / 2, width: logoSize, height: logoSize)
logo.draw(in: logoRect, from: .zero, operation: .sourceOver, fraction: 1.0)

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("错误: PNG 编码失败\n".data(using: .utf8)!)
    exit(1)
}
try! data.write(to: URL(fileURLWithPath: outPath))
print("已生成 \(outPath)")

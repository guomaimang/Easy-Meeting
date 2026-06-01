import AppKit

/// 悬浮窗顶栏的设置入口按钮。
///
/// 与录音按钮共用 24pt 半透明圆底，绘制 SF Symbol `gearshape` 齿轮图标。
/// 自身处理鼠标点击，避免点击落到 `OverlayView` 触发窗口拖拽或缩放。
final class OverlaySettingsButton: NSView {
    private enum Layout {
        static let glyphSize: CGFloat = 14
    }

    /// 点击回调：交给上层打开设置窗口。
    var onOpen: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        toolTip = "打开设置"
        setAccessibilityRole(.button)
        setAccessibilityLabel("打开设置")
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        // 开发环境记录交互输入，便于排查设置入口链路。
        NSLog("悬浮窗设置按钮点击：打开设置窗口")
        onOpen?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // 半透明圆形底，与录音按钮一致，让齿轮在字幕上方可识别又不喧宾夺主。
        let backgroundPath = NSBezierPath(ovalIn: bounds)
        NSColor.white.withAlphaComponent(0.12).setFill()
        backgroundPath.fill()

        drawGearGlyph()
    }

    /// 居中绘制齿轮图标。SF Symbol 默认是模板图，使用 `sourceAtop` 叠加颜色实现统一着色。
    private func drawGearGlyph() {
        let configuration = NSImage.SymbolConfiguration(pointSize: Layout.glyphSize, weight: .semibold)
        guard let symbol = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "设置")?
            .withSymbolConfiguration(configuration) else {
            return
        }
        symbol.isTemplate = true

        let glyphSize = symbol.size
        let glyphRect = NSRect(
            x: bounds.midX - glyphSize.width / 2,
            y: bounds.midY - glyphSize.height / 2,
            width: glyphSize.width,
            height: glyphSize.height
        )

        NSGraphicsContext.saveGraphicsState()
        symbol.draw(in: glyphRect)
        NSColor.white.withAlphaComponent(0.82).set()
        glyphRect.fill(using: .sourceAtop)
        NSGraphicsContext.restoreGraphicsState()
    }
}

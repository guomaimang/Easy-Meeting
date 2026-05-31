import AppKit

/// 悬浮窗角落的录音开关按钮。
///
/// 待机状态绘制一个指向右的播放三角，录音状态绘制一个红色方块。
/// 自身处理鼠标点击，避免点击落到 `OverlayView` 上触发窗口拖拽或缩放。
final class OverlayRecordButton: NSView {
    private enum Layout {
        static let glyphSize: CGFloat = 14
    }

    /// 点击回调：交给上层切换录音状态。
    var onToggle: (() -> Void)?

    /// 当前是否处于录音中，决定绘制三角还是方块。
    var isRecording: Bool = false {
        didSet {
            guard oldValue != isRecording else { return }
            updateAccessibility()
            needsDisplay = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        toolTip = "开始 / 停止录音"
        setAccessibilityRole(.button)
        updateAccessibility()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        // 开发环境记录交互输入，便于排查录音开关链路。
        NSLog("悬浮窗录音按钮点击：%@", isRecording ? "停止录音" : "开始录音")
        onToggle?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // 半透明圆形底，让按钮在字幕上方可被识别又不喧宾夺主。
        let backgroundPath = NSBezierPath(ovalIn: bounds)
        NSColor.white.withAlphaComponent(0.12).setFill()
        backgroundPath.fill()

        let glyphRect = NSRect(
            x: bounds.midX - Layout.glyphSize / 2,
            y: bounds.midY - Layout.glyphSize / 2,
            width: Layout.glyphSize,
            height: Layout.glyphSize
        ).insetBy(dx: 4, dy: 4)
        if isRecording {
            drawStopSquare(in: glyphRect)
        } else {
            drawPlayTriangle(in: glyphRect)
        }
    }

    private func drawPlayTriangle(in rect: NSRect) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: rect.minY))
        path.line(to: NSPoint(x: rect.minX, y: rect.maxY))
        path.line(to: NSPoint(x: rect.maxX, y: rect.midY))
        path.close()
        NSColor.white.withAlphaComponent(0.82).setFill()
        path.fill()
    }

    private func drawStopSquare(in rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
        NSColor.systemRed.setFill()
        path.fill()
    }

    private func updateAccessibility() {
        setAccessibilityLabel(isRecording ? "停止录音" : "开始录音")
    }
}

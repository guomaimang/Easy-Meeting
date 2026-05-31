import AppKit

final class OverlayWindowController: NSWindowController {
    private enum Layout {
        static let defaultSize = NSSize(width: 760, height: 156)
        static let minimumSize = NSSize(width: 420, height: 104)
        static let maximumSize = NSSize(width: 1280, height: 360)
        static let moveStep: CGFloat = 24
        static let resizeStep = NSSize(width: 72, height: 24)
    }

    private let overlayView = OverlayView()
    private var hotKeyController: OverlayHotKeyController?
    private var currentOpacity: CGFloat

    /// 悬浮窗角落录音按钮的点击回调，由状态栏控制器接管录音切换。
    var onToggleRecording: (() -> Void)? {
        get { overlayView.onToggleRecording }
        set { overlayView.onToggleRecording = newValue }
    }

    init(settings: AppSettings = .defaults) {
        currentOpacity = CGFloat(min(max(settings.overlayOpacity, 0.1), 1))

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let initialSize = Layout.defaultSize
        let initialOrigin = NSPoint(
            x: screenFrame.midX - initialSize.width / 2,
            y: screenFrame.minY + 72
        )

        let panel = NSPanel(
            contentRect: NSRect(origin: initialOrigin, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.ignoresMouseEvents = false
        panel.sharingType = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.contentView = overlayView

        super.init(window: panel)

        overlayView.opacity = currentOpacity
        overlayView.fontSize = CGFloat(settings.overlayFontSize)
        overlayView.onDrag = { [weak self] gesture in
            self?.applyDrag(gesture)
        }
        overlayView.update(
            source: "Waiting for microphone input",
            translation: "等待麦克风输入"
        )
        hotKeyController = OverlayHotKeyController(
            moveUp: { [weak self] in self?.moveBy(dx: 0, dy: Layout.moveStep) },
            moveDown: { [weak self] in self?.moveBy(dx: 0, dy: -Layout.moveStep) },
            moveLeft: { [weak self] in self?.moveBy(dx: -Layout.moveStep, dy: 0) },
            moveRight: { [weak self] in self?.moveBy(dx: Layout.moveStep, dy: 0) },
            enlarge: { [weak self] in self?.resizeBy(width: Layout.resizeStep.width, height: Layout.resizeStep.height) },
            shrink: { [weak self] in self?.resizeBy(width: -Layout.resizeStep.width, height: -Layout.resizeStep.height) },
            reset: { [weak self] in self?.resetFrame() }
        )
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        window?.orderFrontRegardless()
    }

    func toggleVisibility() {
        guard let window else { return }

        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.orderFrontRegardless()
        }
    }

    func setOpacity(_ opacity: CGFloat) {
        currentOpacity = min(max(opacity, 0.1), 1)
        overlayView.opacity = currentOpacity
        overlayView.needsDisplay = true
    }

    func setFontSize(_ fontSize: CGFloat) {
        overlayView.fontSize = min(max(fontSize, 14), 34)
    }

    /// 同步录音状态到角落按钮，切换三角 / 方块图标。
    func setRecording(_ isRecording: Bool) {
        overlayView.isRecording = isRecording
    }

    func showReadyStatus() {
        showStatus(source: "Easy Meeting is ready.", translation: "会议助手已准备就绪。")
    }

    func showStatus(source: String, translation: String) {
        overlayView.update(source: source, translation: translation)
        show()
    }

    private func moveBy(dx: CGFloat, dy: CGFloat) {
        guard let window else { return }
        var frame = window.frame
        frame.origin.x += dx
        frame.origin.y += dy
        window.setFrame(clamped(frame), display: true)
        show()
    }

    private func resizeBy(width: CGFloat, height: CGFloat) {
        guard let window else { return }
        var frame = window.frame
        frame.size.width = min(max(frame.width + width, Layout.minimumSize.width), Layout.maximumSize.width)
        frame.size.height = min(max(frame.height + height, Layout.minimumSize.height), Layout.maximumSize.height)
        window.setFrame(clamped(frame), display: true)
        show()
    }

    private func resetFrame() {
        let screenFrame = window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let origin = NSPoint(
            x: screenFrame.midX - Layout.defaultSize.width / 2,
            y: screenFrame.minY + 72
        )
        window?.setFrame(clamped(NSRect(origin: origin, size: Layout.defaultSize)), display: true)
        show()
    }

    private func applyDrag(_ gesture: OverlayDragGesture) {
        guard let window else { return }

        let dx = gesture.currentLocation.x - gesture.startLocation.x
        let dy = gesture.currentLocation.y - gesture.startLocation.y
        let frame = gesture.resizeEdges.isEmpty
            ? movedFrame(from: gesture.startFrame, dx: dx, dy: dy)
            : resizedFrame(from: gesture.startFrame, dx: dx, dy: dy, edges: gesture.resizeEdges)
        window.setFrame(clamped(frame), display: true)
    }

    private func movedFrame(from frame: NSRect, dx: CGFloat, dy: CGFloat) -> NSRect {
        NSRect(
            x: frame.origin.x + dx,
            y: frame.origin.y + dy,
            width: frame.width,
            height: frame.height
        )
    }

    private func resizedFrame(
        from frame: NSRect,
        dx: CGFloat,
        dy: CGFloat,
        edges: OverlayResizeEdges
    ) -> NSRect {
        var next = frame

        if edges.contains(.left) {
            next.origin.x = frame.origin.x + dx
            next.size.width = frame.width - dx
        } else if edges.contains(.right) {
            next.size.width = frame.width + dx
        }

        if edges.contains(.bottom) {
            next.origin.y = frame.origin.y + dy
            next.size.height = frame.height - dy
        } else if edges.contains(.top) {
            next.size.height = frame.height + dy
        }

        next.size.width = min(max(next.width, Layout.minimumSize.width), Layout.maximumSize.width)
        next.size.height = min(max(next.height, Layout.minimumSize.height), Layout.maximumSize.height)

        if edges.contains(.left) {
            next.origin.x = frame.maxX - next.width
        }
        if edges.contains(.bottom) {
            next.origin.y = frame.maxY - next.height
        }

        return next
    }

    private func clamped(_ frame: NSRect) -> NSRect {
        let screenFrame = window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? frame
        var clampedFrame = frame
        let maxX = max(screenFrame.minX, screenFrame.maxX - frame.width)
        let maxY = max(screenFrame.minY, screenFrame.maxY - frame.height)
        clampedFrame.origin.x = min(max(frame.minX, screenFrame.minX), maxX)
        clampedFrame.origin.y = min(max(frame.minY, screenFrame.minY), maxY)
        return clampedFrame
    }
}

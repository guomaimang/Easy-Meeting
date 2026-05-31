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

    init(settings: AppSettings = .defaults) {
        currentOpacity = CGFloat(min(max(settings.overlayOpacity, 0.25), 1))

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
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.contentView = overlayView

        super.init(window: panel)

        overlayView.opacity = currentOpacity
        overlayView.fontSize = CGFloat(settings.overlayFontSize)
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
        currentOpacity = min(max(opacity, 0.25), 1)
        overlayView.opacity = currentOpacity
        overlayView.needsDisplay = true
    }

    func setFontSize(_ fontSize: CGFloat) {
        overlayView.fontSize = min(max(fontSize, 14), 34)
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

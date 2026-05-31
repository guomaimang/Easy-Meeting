import AppKit

final class OverlayWindowController: NSWindowController {
    private let overlayView = OverlayView()
    private var currentOpacity: CGFloat = 0.82

    init() {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let initialSize = NSSize(width: 560, height: 116)
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
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.contentView = overlayView

        super.init(window: panel)

        overlayView.opacity = currentOpacity
        overlayView.update(
            source: "Waiting for microphone input",
            translation: "等待麦克风输入"
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

    func showReadyStatus() {
        showStatus(source: "Easy Meeting is ready.", translation: "会议助手已准备就绪。")
    }

    func showStatus(source: String, translation: String) {
        overlayView.update(source: source, translation: translation)
        show()
    }
}

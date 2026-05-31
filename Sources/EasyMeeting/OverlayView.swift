import AppKit

final class OverlayView: NSView {
    var opacity: CGFloat = 0.82
    var fontSize: CGFloat = 22 {
        didSet {
            applyFonts()
            needsLayout = true
        }
    }
    var onDrag: ((OverlayDragGesture) -> Void)?
    var onToggleRecording: (() -> Void)?

    /// 录音状态，转发给角落按钮切换三角 / 方块图标。
    var isRecording: Bool = false {
        didSet {
            recordButton.isRecording = isRecording
        }
    }

    private let recordButton = OverlayRecordButton()
    private let sourceScrollView = OverlayScrollView()
    private let translationScrollView = OverlayScrollView()
    private let sourceContentView = OverlayContentView()
    private let translationContentView = OverlayContentView()
    private let sourceLabel = NSTextField(wrappingLabelWithString: "")
    private let translationLabel = NSTextField(wrappingLabelWithString: "")
    private let separatorView = NSView()
    private var dragStartLocation: NSPoint?
    private var dragStartFrame: NSRect?
    private var dragEdges: OverlayResizeEdges = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupLabels()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }
        // 录音按钮优先接收点击，其余区域留给拖拽 / 缩放。
        let pointInButton = convert(point, to: recordButton)
        if recordButton.bounds.contains(pointInButton) {
            return recordButton
        }
        return self
    }

    func update(source: String, translation: String) {
        let sourceShouldFollow = sourceScrollView.isPinnedToBottom
        let translationShouldFollow = translationScrollView.isPinnedToBottom
        sourceLabel.stringValue = source
        translationLabel.stringValue = translation
        needsLayout = true
        layoutSubtreeIfNeeded()
        if sourceShouldFollow {
            sourceScrollView.scrollToBottom()
        }
        if translationShouldFollow {
            translationScrollView.scrollToBottom()
        }
    }

    override func scrollWheel(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if point.x < bounds.midX {
            sourceScrollView.scrollWheel(with: event)
        } else {
            translationScrollView.scrollWheel(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        dragStartLocation = window.convertPoint(toScreen: event.locationInWindow)
        dragStartFrame = window.frame
        dragEdges = resizeEdges(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window,
              let dragStartLocation,
              let dragStartFrame else {
            return
        }

        onDrag?(OverlayDragGesture(
            startFrame: dragStartFrame,
            startLocation: dragStartLocation,
            currentLocation: window.convertPoint(toScreen: event.locationInWindow),
            resizeEdges: dragEdges
        ))
    }

    override func mouseUp(with event: NSEvent) {
        dragStartLocation = nil
        dragStartFrame = nil
        dragEdges = []
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let backgroundRect = bounds.insetBy(dx: 0, dy: 0)
        let path = NSBezierPath(roundedRect: backgroundRect, xRadius: 8, yRadius: 8)
        NSColor.black.withAlphaComponent(opacity).setFill()
        path.fill()

        NSColor.white.withAlphaComponent(0.16).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    override func layout() {
        super.layout()

        let inset: CGFloat = 18
        let gap: CGFloat = 18
        let viewport = bounds.insetBy(dx: inset, dy: inset)

        // 录音按钮固定在左上角内边距区域，避开字幕文字。
        let buttonSize: CGFloat = 14
        recordButton.frame = NSRect(x: inset / 2, y: inset / 2, width: buttonSize, height: buttonSize)

        let columnWidth = max((viewport.width - gap) / 2, 120)
        let sourceHeight = max(sourceLabel.heightFor(width: columnWidth), viewport.height)
        let translationHeight = max(translationLabel.heightFor(width: columnWidth), viewport.height)

        sourceScrollView.frame = NSRect(x: viewport.minX, y: viewport.minY, width: columnWidth, height: viewport.height)
        translationScrollView.frame = NSRect(
            x: viewport.minX + columnWidth + gap,
            y: viewport.minY,
            width: columnWidth,
            height: viewport.height
        )
        sourceContentView.frame = NSRect(x: 0, y: 0, width: columnWidth, height: sourceHeight)
        translationContentView.frame = NSRect(x: 0, y: 0, width: columnWidth, height: translationHeight)
        sourceLabel.frame = NSRect(x: 0, y: 0, width: columnWidth, height: sourceHeight)
        translationLabel.frame = NSRect(x: 0, y: 0, width: columnWidth, height: translationHeight)
        separatorView.frame = NSRect(
            x: viewport.minX + columnWidth + gap / 2,
            y: viewport.minY,
            width: 1,
            height: viewport.height
        )
    }

    private func setupLabels() {
        sourceLabel.textColor = .white.withAlphaComponent(0.76)
        sourceLabel.lineBreakMode = .byWordWrapping
        sourceLabel.maximumNumberOfLines = 0

        translationLabel.textColor = .white
        translationLabel.lineBreakMode = .byWordWrapping
        translationLabel.maximumNumberOfLines = 0

        setupScrollView(sourceScrollView, contentView: sourceContentView)
        setupScrollView(translationScrollView, contentView: translationContentView)
        separatorView.wantsLayer = true
        separatorView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.14).cgColor
        applyFonts()

        sourceContentView.addSubview(sourceLabel)
        translationContentView.addSubview(translationLabel)
        addSubview(sourceScrollView)
        addSubview(separatorView)
        addSubview(translationScrollView)

        recordButton.onToggle = { [weak self] in
            self?.onToggleRecording?()
        }
        addSubview(recordButton)
    }

    private func setupScrollView(_ scrollView: OverlayScrollView, contentView: OverlayContentView) {
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true
        scrollView.documentView = contentView
    }

    private func applyFonts() {
        sourceLabel.font = .systemFont(ofSize: fontSize, weight: .regular)
        translationLabel.font = .systemFont(ofSize: max(fontSize - 1, 13), weight: .semibold)
    }

    private func resizeEdges(at point: NSPoint) -> OverlayResizeEdges {
        let zone: CGFloat = 12
        var edges: OverlayResizeEdges = []
        if point.x <= zone {
            edges.insert(.left)
        } else if point.x >= bounds.width - zone {
            edges.insert(.right)
        }
        if point.y <= zone {
            edges.insert(.top)
        } else if point.y >= bounds.height - zone {
            edges.insert(.bottom)
        }
        return edges
    }
}

struct OverlayResizeEdges: OptionSet {
    let rawValue: Int

    static let left = OverlayResizeEdges(rawValue: 1 << 0)
    static let right = OverlayResizeEdges(rawValue: 1 << 1)
    static let top = OverlayResizeEdges(rawValue: 1 << 2)
    static let bottom = OverlayResizeEdges(rawValue: 1 << 3)
}

struct OverlayDragGesture {
    let startFrame: NSRect
    let startLocation: NSPoint
    let currentLocation: NSPoint
    let resizeEdges: OverlayResizeEdges
}

private final class OverlayScrollView: NSScrollView {
    private let bottomTolerance: CGFloat = 6

    var isPinnedToBottom: Bool {
        guard let documentView else { return true }
        let maxY = max(documentView.bounds.height - contentView.bounds.height, 0)
        return contentView.bounds.origin.y >= maxY - bottomTolerance
    }

    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        reflectScrolledClipView(contentView)
    }

    func scrollToBottom() {
        guard let documentView else { return }
        let maxY = max(documentView.bounds.height - contentView.bounds.height, 0)
        contentView.scroll(to: NSPoint(x: 0, y: maxY))
        reflectScrolledClipView(contentView)
    }
}

private final class OverlayContentView: NSView {
    override var isFlipped: Bool {
        true
    }
}

private extension NSTextField {
    func heightFor(width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }
        let size = NSSize(width: width, height: .greatestFiniteMagnitude)
        return ceil(cell?.cellSize(forBounds: NSRect(origin: .zero, size: size)).height ?? 0)
    }
}

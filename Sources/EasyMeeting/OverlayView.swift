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

    private let scrollView = OverlayScrollView()
    private let contentView = OverlayContentView()
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
        bounds.contains(point) ? self : nil
    }

    func update(source: String, translation: String) {
        let shouldFollow = scrollView.isPinnedToBottom
        sourceLabel.stringValue = source
        translationLabel.stringValue = translation
        needsLayout = true
        layoutSubtreeIfNeeded()
        if shouldFollow {
            scrollView.scrollToBottom()
        }
    }

    override func scrollWheel(with event: NSEvent) {
        scrollView.scrollWheel(with: event)
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
        scrollView.frame = viewport

        let columnWidth = max((viewport.width - gap) / 2, 120)
        let labelHeight = max(
            sourceLabel.heightFor(width: columnWidth),
            translationLabel.heightFor(width: columnWidth),
            viewport.height
        )
        let documentHeight = max(labelHeight, viewport.height)
        contentView.frame = NSRect(x: 0, y: 0, width: viewport.width, height: documentHeight)
        sourceLabel.frame = NSRect(x: 0, y: 0, width: columnWidth, height: labelHeight)
        translationLabel.frame = NSRect(x: columnWidth + gap, y: 0, width: columnWidth, height: labelHeight)
        separatorView.frame = NSRect(x: columnWidth + gap / 2, y: 0, width: 1, height: documentHeight)
    }

    private func setupLabels() {
        sourceLabel.textColor = .white.withAlphaComponent(0.76)
        sourceLabel.lineBreakMode = .byWordWrapping
        sourceLabel.maximumNumberOfLines = 0

        translationLabel.textColor = .white
        translationLabel.lineBreakMode = .byWordWrapping
        translationLabel.maximumNumberOfLines = 0

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true
        scrollView.documentView = contentView
        separatorView.wantsLayer = true
        separatorView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.14).cgColor
        applyFonts()

        contentView.addSubview(sourceLabel)
        contentView.addSubview(separatorView)
        contentView.addSubview(translationLabel)
        addSubview(scrollView)
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

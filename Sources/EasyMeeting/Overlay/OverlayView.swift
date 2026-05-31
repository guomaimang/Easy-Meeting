import AppKit

final class OverlayView: NSView {
    private enum Layout {
        static let horizontalInset: CGFloat = 18
        static let topMargin: CGFloat = 8
        static let toolbarHeight: CGFloat = 26
        static let toolbarGap: CGFloat = 10
        static let bottomInset: CGFloat = 18
        static let columnGap: CGFloat = 18
    }

    var opacity: CGFloat = 0.82
    var fontSize: CGFloat = 22 {
        didSet {
            applyFonts()
            needsLayout = true
        }
    }
    var onDrag: ((OverlayDragGesture) -> Void)?
    var onToggleRecording: (() -> Void)? {
        get { toolbar.onToggleRecording }
        set { toolbar.onToggleRecording = newValue }
    }
    var onSelectDevice: ((String) -> Void)? {
        get { toolbar.onSelectDevice }
        set { toolbar.onSelectDevice = newValue }
    }

    /// 录音状态，转发给顶栏切换三角 / 方块图标。
    var isRecording: Bool = false {
        didSet {
            toolbar.isRecording = isRecording
        }
    }

    private let toolbar = OverlayToolbarView()
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

    // PLACEHOLDER_BODY

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
        // hitTest 传入的 point 处于父视图坐标系，而本视图 isFlipped=true，
        // 必须先换算到自身坐标系，否则顶栏控件的命中区会被算到别处。
        let local = superview.map { convert(point, from: $0) } ?? point
        guard bounds.contains(local) else { return nil }
        // 顶栏区域交给子控件（录音按钮 / 麦克风下拉）接收点击，其余区域留给拖拽 / 缩放。
        // hitTest 接收的是「相对接收者父视图」坐标，toolbar 父视图即本视图，故直接传 local。
        if toolbar.frame.contains(local) {
            return toolbar.hitTest(local) ?? self
        }
        return self
    }

    func update(source: String, translation: String) {
        let sourceShouldFollow = sourceScrollView.isPinnedToBottom
        let translationShouldFollow = translationScrollView.isPinnedToBottom
        sourceLabel.stringValue = source
        translationLabel.stringValue = translation
        needsLayout = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if sourceShouldFollow {
                sourceScrollView.scrollToBottom()
            }
            if translationShouldFollow {
                translationScrollView.scrollToBottom()
            }
        }
    }

    /// 刷新顶栏麦克风下拉。
    func updateDevices(_ devices: [AudioInputDevice], selectedID: String?) {
        toolbar.updateDevices(devices, selectedID: selectedID)
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

        let path = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
        NSColor.black.withAlphaComponent(opacity).setFill()
        path.fill()

        NSColor.white.withAlphaComponent(0.16).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    override func layout() {
        super.layout()

        // 顶部留 margin 后放置工具栏，字幕区下移到工具栏之下。
        toolbar.frame = NSRect(
            x: Layout.horizontalInset,
            y: Layout.topMargin,
            width: max(bounds.width - Layout.horizontalInset * 2, 0),
            height: Layout.toolbarHeight
        )

        let contentTop = Layout.topMargin + Layout.toolbarHeight + Layout.toolbarGap
        let contentHeight = max(bounds.height - contentTop - Layout.bottomInset, 0)
        let contentLeft = Layout.horizontalInset
        let contentWidth = max(bounds.width - Layout.horizontalInset * 2, 0)

        let gap = Layout.columnGap
        let columnWidth = max((contentWidth - gap) / 2, 120)
        let sourceHeight = max(sourceLabel.heightFor(width: columnWidth), contentHeight)
        let translationHeight = max(translationLabel.heightFor(width: columnWidth), contentHeight)

        sourceScrollView.frame = NSRect(x: contentLeft, y: contentTop, width: columnWidth, height: contentHeight)
        translationScrollView.frame = NSRect(
            x: contentLeft + columnWidth + gap,
            y: contentTop,
            width: columnWidth,
            height: contentHeight
        )
        sourceContentView.frame = NSRect(x: 0, y: 0, width: columnWidth, height: sourceHeight)
        translationContentView.frame = NSRect(x: 0, y: 0, width: columnWidth, height: translationHeight)
        sourceLabel.frame = NSRect(x: 0, y: 0, width: columnWidth, height: sourceHeight)
        translationLabel.frame = NSRect(x: 0, y: 0, width: columnWidth, height: translationHeight)
        separatorView.frame = NSRect(
            x: contentLeft + columnWidth + gap / 2,
            y: contentTop,
            width: 1,
            height: contentHeight
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
        addSubview(toolbar)
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

private extension NSTextField {
    func heightFor(width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }
        let size = NSSize(width: width, height: .greatestFiniteMagnitude)
        return ceil(cell?.cellSize(forBounds: NSRect(origin: .zero, size: size)).height ?? 0)
    }
}


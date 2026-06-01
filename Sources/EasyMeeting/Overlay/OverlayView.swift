import AppKit

final class OverlayView: NSView {
    enum Layout {
        static let horizontalInset: CGFloat = 18
        static let topMargin: CGFloat = 8
        static let toolbarHeight: CGFloat = 26
        static let toolbarGap: CGFloat = 10
        static let bottomInset: CGFloat = 18
        static let columnGap: CGFloat = 18
        static let minColumnWidth: CGFloat = 120
    }

    var opacity: CGFloat = 0.82
    var fontSize: CGFloat = 22 {
        didSet {
            applyFonts()
        }
    }
    /// 是否显示右侧"备注"栏。关闭时回到原文 / 译文两栏布局。
    var notesEnabled: Bool = false {
        didSet {
            guard notesEnabled != oldValue else { return }
            notesScrollView.isHidden = !notesEnabled
            notesSeparatorView.isHidden = !notesEnabled
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
    /// 顶栏齿轮按钮点击回调，由窗口控制器转发给状态栏控制器打开设置窗口。
    var onOpenSettings: (() -> Void)? {
        get { toolbar.onOpenSettings }
        set { toolbar.onOpenSettings = newValue }
    }

    /// 录音状态，转发给顶栏切换三角 / 方块图标。
    var isRecording: Bool = false {
        didSet {
            toolbar.isRecording = isRecording
        }
    }

    let toolbar = OverlayToolbarView()
    let sourceScrollView = OverlayScrollView()
    let translationScrollView = OverlayScrollView()
    let notesScrollView = OverlayScrollView()
    let separatorView = NSView()
    let notesSeparatorView = NSView()

    /// 缓存当前文本，字号变化时重新应用样式而不丢内容。
    var currentSourceText = ""
    var currentTranslationText = ""
    var currentNotesText = ""

    private var dragStartLocation: NSPoint?
    private var dragStartFrame: NSRect?
    private var dragEdges: OverlayResizeEdges = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupSubtitleViews()
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
        currentSourceText = source
        currentTranslationText = translation
        sourceScrollView.updateText(source, font: sourceFont, color: sourceColor)
        translationScrollView.updateText(translation, font: translationFont, color: translationColor)
    }

    /// 更新备注栏文本。备注属于演示稿，由用户自己掌控阅读位置，
    /// updateText 只在内容改变时才会触发滚动跟随判断，备注栏一般不会贴底，
    /// 因而不会主动打断当前阅读。
    func updateNotes(_ text: String) {
        guard currentNotesText != text else { return }
        currentNotesText = text
        notesScrollView.updateText(text, font: notesFont, color: notesColor)
    }

    /// 刷新顶栏麦克风下拉。
    func updateDevices(_ devices: [AudioInputDevice], selectedID: String?) {
        toolbar.updateDevices(devices, selectedID: selectedID)
    }

    override func scrollWheel(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let columns: [OverlayScrollView] = notesEnabled
            ? [sourceScrollView, translationScrollView, notesScrollView]
            : [sourceScrollView, translationScrollView]
        let columnSpan = max(bounds.width / CGFloat(columns.count), 1)
        let index = max(min(Int(point.x / columnSpan), columns.count - 1), 0)
        columns[index].scrollWheel(with: event)
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

        let columnCount: CGFloat = notesEnabled ? 3 : 2
        let gap = Layout.columnGap
        let columnWidth = max((contentWidth - gap * (columnCount - 1)) / columnCount, Layout.minColumnWidth)

        layoutColumn(
            scrollView: sourceScrollView,
            x: contentLeft, y: contentTop, width: columnWidth, height: contentHeight
        )
        let translationX = contentLeft + columnWidth + gap
        layoutColumn(
            scrollView: translationScrollView,
            x: translationX, y: contentTop, width: columnWidth, height: contentHeight
        )
        separatorView.frame = NSRect(
            x: translationX - gap / 2, y: contentTop, width: 1, height: contentHeight
        )

        if notesEnabled {
            let notesX = translationX + columnWidth + gap
            layoutColumn(
                scrollView: notesScrollView,
                x: notesX, y: contentTop, width: columnWidth, height: contentHeight
            )
            notesSeparatorView.frame = NSRect(
                x: notesX - gap / 2, y: contentTop, width: 1, height: contentHeight
            )
        }
    }
}

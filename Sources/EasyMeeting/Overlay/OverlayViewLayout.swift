import AppKit

extension OverlayView {
    func setupLabels() {
        sourceLabel.textColor = .white.withAlphaComponent(0.76)
        sourceLabel.lineBreakMode = .byWordWrapping
        sourceLabel.maximumNumberOfLines = 0

        translationLabel.textColor = .white
        translationLabel.lineBreakMode = .byWordWrapping
        translationLabel.maximumNumberOfLines = 0

        notesLabel.textColor = .white
        notesLabel.lineBreakMode = .byWordWrapping
        notesLabel.maximumNumberOfLines = 0

        setupScrollView(sourceScrollView, contentView: sourceContentView)
        setupScrollView(translationScrollView, contentView: translationContentView)
        setupScrollView(notesScrollView, contentView: notesContentView)
        notesScrollView.isHidden = true
        notesSeparatorView.isHidden = true
        separatorView.wantsLayer = true
        separatorView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.14).cgColor
        notesSeparatorView.wantsLayer = true
        notesSeparatorView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.14).cgColor
        applyFonts()

        sourceContentView.addSubview(sourceLabel)
        translationContentView.addSubview(translationLabel)
        notesContentView.addSubview(notesLabel)
        addSubview(sourceScrollView)
        addSubview(separatorView)
        addSubview(translationScrollView)
        addSubview(notesSeparatorView)
        addSubview(notesScrollView)
        addSubview(toolbar)
    }

    func setupScrollView(_ scrollView: OverlayScrollView, contentView: OverlayContentView) {
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true
        scrollView.documentView = contentView
    }

    func applyFonts() {
        sourceLabel.font = .systemFont(ofSize: fontSize, weight: .regular)
        translationLabel.font = .systemFont(ofSize: max(fontSize - 1, 13), weight: .semibold)
        notesLabel.font = .systemFont(ofSize: fontSize, weight: .regular)
    }

    func resizeEdges(at point: NSPoint) -> OverlayResizeEdges {
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

    func layoutColumn(
        scrollView: OverlayScrollView,
        content: OverlayContentView,
        label: NSTextField,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat
    ) {
        let labelHeight = max(label.heightFor(width: width), height)
        scrollView.frame = NSRect(x: x, y: y, width: width, height: height)
        content.frame = NSRect(x: 0, y: 0, width: width, height: labelHeight)
        label.frame = NSRect(x: 0, y: 0, width: width, height: labelHeight)
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

extension NSTextField {
    func heightFor(width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }
        let size = NSSize(width: width, height: .greatestFiniteMagnitude)
        return ceil(cell?.cellSize(forBounds: NSRect(origin: .zero, size: size)).height ?? 0)
    }
}

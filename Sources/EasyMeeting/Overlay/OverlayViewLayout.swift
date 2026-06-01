import AppKit

extension OverlayView {
    /// 字幕字体：原文用常规、译文加粗略小、备注与原文同字号。
    var sourceFont: NSFont { .systemFont(ofSize: fontSize, weight: .regular) }
    var translationFont: NSFont { .systemFont(ofSize: max(fontSize - 1, 13), weight: .semibold) }
    var notesFont: NSFont { .systemFont(ofSize: fontSize, weight: .regular) }

    /// 字幕颜色：原文偏淡、译文最显眼、备注同译文亮度。
    var sourceColor: NSColor { .white.withAlphaComponent(0.76) }
    var translationColor: NSColor { .white }
    var notesColor: NSColor { .white }

    /// 装配三列字幕视图与两根分隔线，并把工具栏放最上层。
    /// 真实文本在 `update(source:translation:)` / `updateNotes` 时通过
    /// `OverlayScrollView.updateText` 写入，这里只负责样式与层级。
    func setupSubtitleViews() {
        notesScrollView.isHidden = true
        notesSeparatorView.isHidden = true

        separatorView.wantsLayer = true
        separatorView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.14).cgColor
        notesSeparatorView.wantsLayer = true
        notesSeparatorView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.14).cgColor

        addSubview(sourceScrollView)
        addSubview(separatorView)
        addSubview(translationScrollView)
        addSubview(notesSeparatorView)
        addSubview(notesScrollView)
        addSubview(toolbar)

        applyFonts()
    }

    /// 字号变化时刷新已显示文本的样式。`OverlayScrollView.updateText` 在内容
    /// 未变时只走属性更新，长字幕场景下成本极低。
    func applyFonts() {
        sourceScrollView.updateText(currentSourceText, font: sourceFont, color: sourceColor)
        translationScrollView.updateText(currentTranslationText, font: translationFont, color: translationColor)
        notesScrollView.updateText(currentNotesText, font: notesFont, color: notesColor)
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

    /// 单列字幕布局：只设置 NSScrollView 的 frame，textView 由 TextKit
    /// 通过 `widthTracksTextView` + `autoresizingMask` 自适应宽高，
    /// 不再像旧版那样调用 NSTextField 的 `cellSize(forBounds:)` 计算高度，
    /// 长字幕和窗口缩放都不会阻塞主线程。
    func layoutColumn(
        scrollView: OverlayScrollView,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat
    ) {
        scrollView.frame = NSRect(x: x, y: y, width: width, height: height)
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

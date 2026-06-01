import AppKit

/// 字幕列：NSScrollView + NSTextView 组合。
///
/// 旧实现用 NSTextField(wrappingLabel) 当 documentView，每次更新都要重新
/// 触发 `cell.cellSize(forBounds:)` 测量整段历史，文本一长就严重卡顿，
/// 调整窗口尺寸时同样阻塞主线程。改用 NSTextView 让 TextKit 接管排版，
/// `NSLayoutManager` 走惰性 + 增量布局，长字幕和 resize 都流畅。
///
/// 同时承载「贴底自动跟随」逻辑：用户停在底部时新内容自动滚到底，
/// 上滚查看历史时则保持位置不动。
final class OverlayScrollView: NSScrollView {
    /// 距底部多少像素以内仍视为「贴底」，避免浮点误差判断失败。
    private let bottomTolerance: CGFloat = 6
    let textView: OverlaySubtitleTextView

    override init(frame frameRect: NSRect) {
        textView = OverlaySubtitleTextView(
            frame: NSRect(origin: .zero, size: frameRect.size)
        )
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) { nil }

    /// 当前是否贴在底部。判断依据是 contentView 的滚动偏移已逼近最大值。
    var isPinnedToBottom: Bool {
        guard let documentView else { return true }
        let docHeight = documentView.bounds.height
        let visibleHeight = contentView.bounds.height
        let maxY = max(docHeight - visibleHeight, 0)
        return contentView.bounds.origin.y >= maxY - bottomTolerance
    }

    /// 滚到底部前先强制 TextKit 完成排版，否则刚改完文本时 contentSize
    /// 可能仍是旧值，导致 maxY 偏小，看起来「不滚了」。
    func scrollToBottom() {
        ensureLayout()
        guard let documentView else { return }
        let docHeight = documentView.bounds.height
        let visibleHeight = contentView.bounds.height
        let maxY = max(docHeight - visibleHeight, 0)
        contentView.scroll(to: NSPoint(x: 0, y: maxY))
        reflectScrolledClipView(contentView)
    }

    /// 写入新字幕文本并按需滚到底。
    /// - 内容未变只刷新样式，避免无谓的 textStorage 全量替换；
    /// - 内容变化前先快照「是否贴底」，更新后再强制 layout，最后再滚到底，
    ///   确保新增文本可见且不会打断用户正在查看历史的位置。
    func updateText(_ text: String, font: NSFont, color: NSColor) {
        let storage = textView.textStorage!
        let attrs = typingAttributes(font: font, color: color)

        if storage.string == text {
            // 仅样式变化（例如调字号）时刷新一次属性。
            applyTypingAttributes(font: font, color: color)
            if storage.length > 0 {
                storage.beginEditing()
                storage.setAttributes(attrs, range: NSRange(location: 0, length: storage.length))
                storage.endEditing()
            }
            return
        }

        let wasPinned = isPinnedToBottom
        applyTypingAttributes(font: font, color: color)

        storage.beginEditing()
        storage.replaceCharacters(
            in: NSRange(location: 0, length: storage.length),
            with: text
        )
        if storage.length > 0 {
            storage.setAttributes(attrs, range: NSRange(location: 0, length: storage.length))
        }
        storage.endEditing()

        if wasPinned {
            // ensureLayout 内部会按需排版可见区，是同步 + 增量的，长文本也廉价。
            scrollToBottom()
        }
    }

    private func ensureLayout() {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)
    }

    private func configure() {
        drawsBackground = false
        hasVerticalScroller = false
        hasHorizontalScroller = false
        borderType = .noBorder
        autohidesScrollers = true
        verticalScrollElasticity = .allowed
        horizontalScrollElasticity = .none

        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isRichText = false
        textView.allowsUndo = false

        if let container = textView.textContainer {
            container.widthTracksTextView = true
            container.lineFragmentPadding = 0
        }
        documentView = textView
    }

    private func applyTypingAttributes(font: NSFont, color: NSColor) {
        textView.font = font
        textView.textColor = color
        textView.typingAttributes = typingAttributes(font: font, color: color)
    }

    private func typingAttributes(font: NSFont, color: NSColor) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
    }
}

/// 自定义 NSTextView：不抢第一响应者，避免悬浮窗内字幕区接管键盘焦点。
/// OverlayView.hitTest 已统一拦截非工具栏区域的点击，textView 不会收到鼠标事件，
/// 真正的滚动来自 OverlayView.scrollWheel 显式转发到对应列。
final class OverlaySubtitleTextView: NSTextView {
    override var acceptsFirstResponder: Bool { false }
}

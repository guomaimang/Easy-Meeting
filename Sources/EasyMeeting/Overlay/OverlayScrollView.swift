import AppKit

/// 字幕滚动视图，支持「贴底自动跟随」：用户停在底部时新内容自动滚到底，
/// 用户上滚查看历史时则保持位置不动。
final class OverlayScrollView: NSScrollView {
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

/// 字幕文本承载视图，翻转坐标系让文本从顶部向下排列。
final class OverlayContentView: NSView {
    override var isFlipped: Bool {
        true
    }
}

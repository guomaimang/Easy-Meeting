import AppKit

final class OverlayView: NSView {
    var opacity: CGFloat = 0.82

    private let sourceLabel = NSTextField(labelWithString: "")
    private let translationLabel = NSTextField(labelWithString: "")

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

    func update(source: String, translation: String) {
        sourceLabel.stringValue = source
        translationLabel.stringValue = translation
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
        let labelWidth = max(bounds.width - inset * 2, 120)
        sourceLabel.frame = NSRect(x: inset, y: 18, width: labelWidth, height: 28)
        translationLabel.frame = NSRect(x: inset, y: 52, width: labelWidth, height: 42)
    }

    private func setupLabels() {
        sourceLabel.font = .systemFont(ofSize: 15, weight: .regular)
        sourceLabel.textColor = .white.withAlphaComponent(0.76)
        sourceLabel.lineBreakMode = .byTruncatingTail
        sourceLabel.maximumNumberOfLines = 1

        translationLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        translationLabel.textColor = .white
        translationLabel.lineBreakMode = .byTruncatingTail
        translationLabel.maximumNumberOfLines = 1

        addSubview(sourceLabel)
        addSubview(translationLabel)
    }
}

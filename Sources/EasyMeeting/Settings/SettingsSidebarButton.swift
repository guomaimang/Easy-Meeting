import AppKit

final class SettingsSidebarButton: NSButton {
    let section: SettingsSection
    var isSelected = false {
        didSet {
            needsDisplay = true
        }
    }

    private let symbolImage: NSImage?

    init(section: SettingsSection, target: AnyObject?, action: Selector?) {
        self.section = section
        let baseImage = NSImage(systemSymbolName: section.iconName, accessibilityDescription: section.title)
        self.symbolImage = baseImage?.withSymbolConfiguration(.init(pointSize: 15, weight: .semibold))
        super.init(frame: .zero)
        self.target = target
        self.action = action
        title = section.title
        isBordered = false
        imagePosition = .noImage
        alignment = .left
        focusRingType = .none
        setButtonType(.momentaryChange)
        wantsLayer = true
        toolTip = section.title
        setAccessibilityLabel(section.title)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 176, height: 34)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(nil)
        super.mouseDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        drawBackground()
        drawIcon()
        drawTitle()
    }

    private func drawBackground() {
        guard isSelected || isHighlighted else { return }
        let color = isSelected ? NSColor.controlAccentColor : NSColor.selectedControlColor.withAlphaComponent(0.16)
        color.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7).fill()
    }

    private func drawIcon() {
        guard let image = symbolImage else { return }
        let iconRect = NSRect(x: 14, y: 7, width: 20, height: 20)
        let imageRect = NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        let color = isSelected ? NSColor.white : NSColor.secondaryLabelColor

        color.set()
        image.draw(in: iconRect, from: imageRect, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    private func drawTitle() {
        let color = isSelected ? NSColor.white : NSColor.labelColor
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: color
        ]
        let attributedTitle = NSAttributedString(string: section.title, attributes: attributes)
        attributedTitle.draw(in: NSRect(x: 44, y: 7, width: max(bounds.width - 52, 40), height: 20))
    }
}

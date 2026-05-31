import AppKit

final class SettingsSidebarButton: NSControl {
    let section: SettingsSection
    var isSelected = false {
        didSet {
            updateColors()
            needsDisplay = true
        }
    }

    private let titleField = NSTextField(labelWithString: "")
    private let iconView = NSImageView()

    init(section: SettingsSection, target: AnyObject?, action: Selector?) {
        self.section = section
        super.init(frame: .zero)
        self.target = target
        self.action = action
        wantsLayer = true
        setupViews()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func layout() {
        super.layout()
        iconView.frame = NSRect(x: 14, y: 7, width: 20, height: 20)
        titleField.frame = NSRect(x: 44, y: 6, width: max(bounds.width - 52, 40), height: 22)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard isSelected else { return }
        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7).fill()
    }

    override func mouseDown(with event: NSEvent) {
        sendAction(action, to: target)
    }

    private func setupViews() {
        titleField.stringValue = section.title
        titleField.font = .systemFont(ofSize: 14, weight: .semibold)
        addSubview(titleField)

        iconView.image = NSImage(systemSymbolName: section.iconName, accessibilityDescription: section.title)
        iconView.symbolConfiguration = .init(pointSize: 15, weight: .semibold)
        addSubview(iconView)
        updateColors()
    }

    private func updateColors() {
        titleField.textColor = isSelected ? .white : .labelColor
        iconView.contentTintColor = isSelected ? .white : .secondaryLabelColor
    }
}

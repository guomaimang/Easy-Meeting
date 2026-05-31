import AppKit

@MainActor
extension SettingsWindowController {
    func setupSidebar(in contentView: NSView) {
        let background = SettingsBackgroundView(frame: NSRect(x: 0, y: 0, width: 204, height: 560))
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.84).cgColor
        contentView.addSubview(background)

        var currentGroup: String?
        var y: CGFloat = 492
        SettingsSection.allCases.forEach { section in
            if currentGroup != section.groupTitle {
                currentGroup = section.groupTitle
                let header = sidebarHeader(section.groupTitle)
                header.frame = NSRect(x: 22, y: y, width: 160, height: 18)
                background.addSubview(header)
                y -= 34
            }

            let button = SettingsSidebarButton(section: section, target: self, action: #selector(selectSection))
            button.frame = NSRect(x: 14, y: y, width: 176, height: 34)
            background.addSubview(button)
            sectionButtons[section] = button
            y -= 42
        }
    }

    func updateSidebarSelection() {
        sectionButtons.forEach { section, button in
            guard let button = button as? SettingsSidebarButton else { return }
            button.isSelected = section == selectedSection
        }
    }

    private func sidebarHeader(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .tertiaryLabelColor
        label.frame.size = NSSize(width: 168, height: 18)
        return label
    }
}

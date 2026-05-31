import AppKit

@MainActor
extension SettingsWindowController {
    func setupSidebar(in contentView: NSView) {
        let background = SettingsBackgroundView(frame: NSRect(x: 0, y: 0, width: 204, height: 620))
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.84).cgColor
        contentView.addSubview(background)

        sidebarStack.orientation = .vertical
        sidebarStack.spacing = 7
        sidebarStack.alignment = .leading
        sidebarStack.frame = NSRect(x: 18, y: 328, width: 168, height: 220)
        contentView.addSubview(sidebarStack)

        var currentGroup: String?
        SettingsSection.allCases.forEach { section in
            if currentGroup != section.groupTitle {
                currentGroup = section.groupTitle
                sidebarStack.addArrangedSubview(sidebarHeader(section.groupTitle))
            }

            let button = SettingsSidebarButton(section: section, target: self, action: #selector(selectSection))
            button.frame.size = NSSize(width: 168, height: 34)
            sidebarStack.addArrangedSubview(button)
            sectionButtons[section] = button
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

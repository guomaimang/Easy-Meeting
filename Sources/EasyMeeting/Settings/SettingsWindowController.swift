import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    private let settingsStore: AppSettingsStore
    private let providerPopUp = NSPopUpButton()
    private let resourceField = NSTextField()
    private let appKeyField = NSSecureTextField()
    private let accessKeyField = NSSecureTextField()
    private let statusLabel = NSTextField(labelWithString: "")

    init(settingsStore: AppSettingsStore) {
        self.settingsStore = settingsStore

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 292),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Easy Meeting 设置"
        window.center()

        super.init(window: window)
        setupContent()
        loadSettings()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        loadSettings()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    @objc private func save() {
        do {
            let settings = AppSettings(
                speechProvider: selectedProvider(),
                volcengineResourceID: resourceField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
                volcengineAppKey: appKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
                volcengineAccessKey: accessKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            try settingsStore.save(settings)
            statusLabel.stringValue = "已保存"
        } catch {
            statusLabel.stringValue = error.localizedDescription
        }
    }

    private func setupContent() {
        guard let contentView = window?.contentView else { return }

        providerPopUp.addItems(withTitles: SpeechProvider.allCases.map(\.title))
        providerPopUp.frame = NSRect(x: 176, y: 228, width: 250, height: 28)
        contentView.addSubview(providerPopUp)

        resourceField.frame = NSRect(x: 176, y: 178, width: 250, height: 24)
        contentView.addSubview(resourceField)

        appKeyField.frame = NSRect(x: 176, y: 128, width: 250, height: 24)
        contentView.addSubview(appKeyField)

        accessKeyField.frame = NSRect(x: 176, y: 78, width: 250, height: 24)
        contentView.addSubview(accessKeyField)

        statusLabel.frame = NSRect(x: 176, y: 34, width: 180, height: 24)
        statusLabel.textColor = .secondaryLabelColor
        contentView.addSubview(statusLabel)

        addLabel("语音服务", y: 232)
        addLabel("火山 Resource ID", y: 182)
        addLabel("火山 App Key", y: 132)
        addLabel("火山 Access Key", y: 82)

        let saveButton = NSButton(title: "保存", target: self, action: #selector(save))
        saveButton.frame = NSRect(x: 362, y: 30, width: 80, height: 30)
        contentView.addSubview(saveButton)
    }

    private func addLabel(_ title: String, y: CGFloat) {
        let label = NSTextField(labelWithString: title)
        label.frame = NSRect(x: 44, y: y, width: 116, height: 22)
        window?.contentView?.addSubview(label)
    }

    private func loadSettings() {
        let settings = settingsStore.settings
        if let index = SpeechProvider.allCases.firstIndex(of: settings.speechProvider) {
            providerPopUp.selectItem(at: index)
        }
        resourceField.stringValue = settings.volcengineResourceID
        appKeyField.stringValue = settings.volcengineAppKey
        accessKeyField.stringValue = settings.volcengineAccessKey
        statusLabel.stringValue = ""
    }

    private func selectedProvider() -> SpeechProvider {
        let index = providerPopUp.indexOfSelectedItem
        guard SpeechProvider.allCases.indices.contains(index) else {
            return .volcengine
        }

        return SpeechProvider.allCases[index]
    }
}

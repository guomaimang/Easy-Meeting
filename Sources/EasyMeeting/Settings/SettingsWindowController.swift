import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    private let settingsStore: AppSettingsStore
    private let audioDeviceManager: AudioDeviceManager
    private let overlayController: OverlayWindowController
    private let sidebarStack = NSStackView()
    private let contentContainer = NSView()
    private let providerPopUp = NSPopUpButton()
    private let resourceValueLabel = NSTextField(labelWithString: AppSettings.volcengineResourceID)
    private let apiKeyField = NSSecureTextField()
    private let opacitySlider = NSSlider(value: 0.82, minValue: 0.25, maxValue: 1, target: nil, action: nil)
    private let opacityValueLabel = NSTextField(labelWithString: "")
    private let helperStatusField = NSTextField(labelWithString: "")
    private let microphoneStatusField = NSTextField(labelWithString: "")
    private let audioDevicePopUp = NSPopUpButton()
    private let statusLabel = NSTextField(labelWithString: "")
    private var sectionButtons: [SettingsSection: NSButton] = [:]
    private var selectedSection: SettingsSection = .app

    init(
        settingsStore: AppSettingsStore,
        audioDeviceManager: AudioDeviceManager,
        overlayController: OverlayWindowController
    ) {
        self.settingsStore = settingsStore
        self.audioDeviceManager = audioDeviceManager
        self.overlayController = overlayController

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 740, height: 420),
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
            let settings = currentSettings()
            try settingsStore.save(settings)
            overlayController.setOpacity(CGFloat(settings.overlayOpacity))
            helperStatusField.stringValue = VolcengineHelperRuntime.diagnostic(settings: settings)
            statusLabel.stringValue = "已保存"
        } catch {
            statusLabel.stringValue = error.localizedDescription
        }
    }

    @objc private func checkConfiguration() {
        do {
            let settings = currentSettings()
            try settingsStore.save(settings)
            helperStatusField.stringValue = VolcengineHelperRuntime.diagnostic(settings: settings)
            statusLabel.stringValue = "已检查"
        } catch {
            statusLabel.stringValue = error.localizedDescription
        }
    }

    @objc private func selectSection(_ sender: NSButton) {
        guard let section = sender.representedObject as? SettingsSection else { return }
        selectedSection = section
        renderSelectedSection()
    }

    @objc private func changeOpacity() {
        updateOpacityLabel()
        overlayController.setOpacity(CGFloat(opacitySlider.doubleValue))
    }

    @objc private func requestMicrophonePermission() {
        Task { @MainActor in
            let authorization = await audioDeviceManager.requestPermission()
            microphoneStatusField.stringValue = authorization.title
            reloadAudioDevices()
            statusLabel.stringValue = "麦克风权限已更新"
        }
    }

    @objc private func refreshAudioDevices() {
        audioDeviceManager.refreshDevices()
        microphoneStatusField.stringValue = audioDeviceManager.authorization.title
        reloadAudioDevices()
        statusLabel.stringValue = "输入设备已刷新"
    }

    @objc private func selectAudioDevice() {
        guard let deviceID = audioDevicePopUp.selectedItem?.representedObject as? String else { return }
        audioDeviceManager.selectDevice(id: deviceID)
        statusLabel.stringValue = "已选择麦克风：\(audioDeviceManager.selectedDeviceName())"
    }

    private func setupContent() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true

        sidebarStack.orientation = .vertical
        sidebarStack.spacing = 8
        sidebarStack.alignment = .leading
        sidebarStack.frame = NSRect(x: 16, y: 72, width: 128, height: 300)
        contentView.addSubview(sidebarStack)

        SettingsSection.allCases.forEach { section in
            let button = NSButton(title: section.title, target: self, action: #selector(selectSection))
            button.representedObject = section
            button.setButtonType(.pushOnPushOff)
            button.bezelStyle = .rounded
            button.frame.size = NSSize(width: 112, height: 30)
            sidebarStack.addArrangedSubview(button)
            sectionButtons[section] = button
        }

        contentContainer.frame = NSRect(x: 164, y: 72, width: 544, height: 300)
        contentContainer.wantsLayer = true
        contentView.addSubview(contentContainer)

        statusLabel.frame = NSRect(x: 164, y: 24, width: 240, height: 24)
        statusLabel.textColor = .secondaryLabelColor
        contentView.addSubview(statusLabel)

        let saveButton = NSButton(title: "保存", target: self, action: #selector(save))
        saveButton.frame = NSRect(x: 628, y: 20, width: 80, height: 30)
        contentView.addSubview(saveButton)

        providerPopUp.addItems(withTitles: SpeechProvider.allCases.map(\.title))
        opacitySlider.target = self
        opacitySlider.action = #selector(changeOpacity)
        audioDevicePopUp.target = self
        audioDevicePopUp.action = #selector(selectAudioDevice)
        helperStatusField.lineBreakMode = .byTruncatingMiddle
    }

    private func loadSettings() {
        let settings = settingsStore.settings
        if let index = SpeechProvider.allCases.firstIndex(of: settings.speechProvider) {
            providerPopUp.selectItem(at: index)
        }
        apiKeyField.stringValue = settings.volcengineAPIKey
        opacitySlider.doubleValue = settings.overlayOpacity
        helperStatusField.stringValue = VolcengineHelperRuntime.diagnostic(settings: settings)
        microphoneStatusField.stringValue = audioDeviceManager.authorization.title
        reloadAudioDevices()
        updateOpacityLabel()
        statusLabel.stringValue = ""
        renderSelectedSection()
    }

    private func renderSelectedSection() {
        sectionButtons.forEach { section, button in
            button.state = section == selectedSection ? .on : .off
        }
        contentContainer.subviews.forEach { $0.removeFromSuperview() }

        let page: NSView
        switch selectedSection {
        case .app:
            page = appPage()
        case .speech:
            page = speechPage()
        case .microphone:
            page = microphonePage()
        }
        page.frame = contentContainer.bounds
        page.autoresizingMask = [.width, .height]
        contentContainer.addSubview(page)
    }

    private func appPage() -> NSView {
        let page = pageView(title: "程序配置")
        addLabel("悬浮窗透明度", to: page, y: 206)
        opacitySlider.frame = NSRect(x: 148, y: 204, width: 240, height: 24)
        page.addSubview(opacitySlider)
        opacityValueLabel.frame = NSRect(x: 404, y: 204, width: 72, height: 22)
        opacityValueLabel.textColor = .secondaryLabelColor
        page.addSubview(opacityValueLabel)
        return page
    }

    private func speechPage() -> NSView {
        let page = pageView(title: "语音配置")
        addLabel("语音服务", to: page, y: 224)
        providerPopUp.frame = NSRect(x: 148, y: 220, width: 280, height: 28)
        page.addSubview(providerPopUp)

        addLabel("Resource ID", to: page, y: 176)
        resourceValueLabel.frame = NSRect(x: 148, y: 178, width: 280, height: 22)
        resourceValueLabel.textColor = .secondaryLabelColor
        page.addSubview(resourceValueLabel)

        addLabel("火山 API Key", to: page, y: 128)
        apiKeyField.frame = NSRect(x: 148, y: 124, width: 280, height: 24)
        page.addSubview(apiKeyField)

        addLabel("本地 helper", to: page, y: 80)
        helperStatusField.frame = NSRect(x: 148, y: 80, width: 340, height: 22)
        helperStatusField.textColor = .secondaryLabelColor
        page.addSubview(helperStatusField)

        let checkButton = NSButton(title: "检查配置", target: self, action: #selector(checkConfiguration))
        checkButton.frame = NSRect(x: 148, y: 30, width: 92, height: 30)
        page.addSubview(checkButton)
        return page
    }

    private func microphonePage() -> NSView {
        let page = pageView(title: "麦克风配置")
        addLabel("权限状态", to: page, y: 224)
        microphoneStatusField.frame = NSRect(x: 148, y: 224, width: 280, height: 22)
        microphoneStatusField.textColor = .secondaryLabelColor
        page.addSubview(microphoneStatusField)

        addLabel("输入设备", to: page, y: 176)
        audioDevicePopUp.frame = NSRect(x: 148, y: 172, width: 300, height: 28)
        page.addSubview(audioDevicePopUp)

        let permissionButton = NSButton(title: "请求权限", target: self, action: #selector(requestMicrophonePermission))
        permissionButton.frame = NSRect(x: 148, y: 116, width: 92, height: 30)
        page.addSubview(permissionButton)

        let refreshButton = NSButton(title: "刷新设备", target: self, action: #selector(refreshAudioDevices))
        refreshButton.frame = NSRect(x: 252, y: 116, width: 92, height: 30)
        page.addSubview(refreshButton)
        return page
    }

    private func pageView(title: String) -> NSView {
        let page = NSView(frame: contentContainer.bounds)
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.frame = NSRect(x: 0, y: 262, width: 240, height: 24)
        page.addSubview(titleLabel)
        return page
    }

    private func addLabel(_ title: String, to view: NSView, y: CGFloat) {
        let label = NSTextField(labelWithString: title)
        label.frame = NSRect(x: 0, y: y, width: 120, height: 22)
        view.addSubview(label)
    }

    private func reloadAudioDevices() {
        audioDevicePopUp.removeAllItems()
        audioDeviceManager.devices.forEach { device in
            let title = device.isDefault ? "\(device.name)（系统默认）" : device.name
            audioDevicePopUp.addItem(withTitle: title)
            audioDevicePopUp.lastItem?.representedObject = device.id
        }

        guard audioDeviceManager.devices.isEmpty == false else {
            audioDevicePopUp.addItem(withTitle: "没有发现输入设备")
            audioDevicePopUp.isEnabled = false
            return
        }

        audioDevicePopUp.isEnabled = true
        if let selectedDeviceID = audioDeviceManager.selectedDeviceID,
           let index = audioDevicePopUp.itemArray.firstIndex(where: { $0.representedObject as? String == selectedDeviceID }) {
            audioDevicePopUp.selectItem(at: index)
        }
    }

    private func updateOpacityLabel() {
        opacityValueLabel.stringValue = "\(Int(opacitySlider.doubleValue * 100))%"
    }

    private func currentSettings() -> AppSettings {
        AppSettings(
            speechProvider: selectedProvider(),
            volcengineAPIKey: apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            overlayOpacity: opacitySlider.doubleValue
        )
    }

    private func selectedProvider() -> SpeechProvider {
        let index = providerPopUp.indexOfSelectedItem
        guard SpeechProvider.allCases.indices.contains(index) else {
            return .volcengine
        }
        return SpeechProvider.allCases[index]
    }
}

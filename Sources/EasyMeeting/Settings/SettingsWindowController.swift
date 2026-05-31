import AppKit

@MainActor
final class SettingsWindowController: NSWindowController, NSTextFieldDelegate {
    let settingsStore: AppSettingsStore
    let audioDeviceManager: AudioDeviceManager
    let overlayController: OverlayWindowController
    let contentContainer = SettingsBackgroundView()
    let providerPopUp = NSPopUpButton()
    let speechModePopUp = NSPopUpButton()
    let sourceLanguagePopUp = NSPopUpButton()
    let targetLanguagePopUp = NSPopUpButton()
    let speechModeDetailLabel = NSTextField(labelWithString: "")
    let speechLanguageWarningLabel = NSTextField(labelWithString: "")
    let resourceValueLabel = NSTextField(labelWithString: AppSettings.volcengineResourceID)
    let apiKeyField = NSSecureTextField()
    let apiKeyVisibleField = NSTextField()
    let apiKeyLengthLabel = NSTextField(labelWithString: "")
    let regionField = NSTextField()
    let apiKeyRowTitle = NSTextField(labelWithString: "")
    let pasteAPIKeyButton = NSButton(title: "粘贴", target: nil, action: nil)
    let revealAPIKeyButton = NSButton(title: "显示", target: nil, action: nil)
    let clearAPIKeyButton = NSButton(title: "清空", target: nil, action: nil)
    let opacitySlider = NSSlider(value: 0.82, minValue: 0.25, maxValue: 1, target: nil, action: nil)
    let opacityValueLabel = NSTextField(labelWithString: "")
    let fontSizeSlider = NSSlider(value: 22, minValue: 14, maxValue: 34, target: nil, action: nil)
    let fontSizeValueLabel = NSTextField(labelWithString: "")
    let helperStatusField = NSTextField(labelWithString: "")
    let microphoneStatusField = NSTextField(labelWithString: "")
    let audioDevicePopUp = NSPopUpButton()
    let statusLabel = NSTextField(labelWithString: "")
    var sectionButtons: [SettingsSection: NSControl] = [:]
    var selectedSection: SettingsSection = .app
    var apiKeyVisible = false
    // 按服务商分别缓存正在编辑的密钥，切换 provider 不丢输入
    var volcengineKeyDraft = ""
    var azureKeyDraft = ""
    var lastSelectedProvider: SpeechProvider?

    init(
        settingsStore: AppSettingsStore,
        audioDeviceManager: AudioDeviceManager,
        overlayController: OverlayWindowController
    ) {
        self.settingsStore = settingsStore
        self.audioDeviceManager = audioDeviceManager
        self.overlayController = overlayController

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 840, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Easy Meeting 设置"
        window.minSize = NSSize(width: 840, height: 560)
        window.isMovableByWindowBackground = true
        window.contentView = SettingsBackgroundView(frame: NSRect(x: 0, y: 0, width: 840, height: 560))
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

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(nil)
        super.mouseDown(with: event)
    }

    @objc private func save() {
        do {
            guard validateSpeechLanguages() else { return }
            let settings = currentSettings()
            try settingsStore.save(settings)
            overlayController.setOpacity(CGFloat(settings.overlayOpacity))
            overlayController.setFontSize(CGFloat(settings.overlayFontSize))
            helperStatusField.stringValue = currentDiagnostic(for: settings)
            statusLabel.stringValue = "已保存"
        } catch {
            statusLabel.stringValue = error.localizedDescription
        }
    }

    @objc func checkConfiguration() {
        do {
            guard validateSpeechLanguages() else { return }
            let settings = currentSettings()
            try settingsStore.save(settings)
            overlayController.setOpacity(CGFloat(settings.overlayOpacity))
            overlayController.setFontSize(CGFloat(settings.overlayFontSize))
            helperStatusField.stringValue = currentDiagnostic(for: settings)
            statusLabel.stringValue = "已检查"
        } catch {
            statusLabel.stringValue = error.localizedDescription
        }
    }

    @objc func changeProvider() {
        // 先把当前输入框内容写回对应草稿，再切换显示新 provider 的密钥
        if let previous = lastSelectedProvider {
            if previous == .azure {
                azureKeyDraft = currentAPIKey()
            } else {
                volcengineKeyDraft = currentAPIKey()
            }
        }
        lastSelectedProvider = selectedProvider()
        setAPIKey(currentProviderKeyDraft())
        // 切换 provider：代号体系不同，直接用新服务商默认语种重填下拉框
        let provider = selectedProvider()
        reloadLanguagePopUps(
            sourceCode: SpeechLanguageCatalog.defaultSourceCode(for: provider),
            targetCode: SpeechLanguageCatalog.defaultTargetCode(for: provider)
        )
        updateSpeechModeDetail()
        renderSelectedSection()
    }

    @objc func selectSection(_ sender: NSControl) {
        let section: SettingsSection?
        if let sidebarButton = sender as? SettingsSidebarButton {
            section = sidebarButton.section
        } else {
            section = SettingsSection(rawValue: sender.tag)
        }
        guard let section else { return }
        #if DEBUG
        NSLog("设置侧栏切换：%@", section.title)
        #endif
        selectedSection = section
        renderSelectedSection()
    }

    @objc private func changeOpacity() {
        updateOpacityLabel()
        overlayController.setOpacity(CGFloat(opacitySlider.doubleValue))
    }

    @objc func changeFontSize() {
        updateFontSizeLabel()
        overlayController.setFontSize(CGFloat(fontSizeSlider.doubleValue))
    }

    @objc func requestMicrophonePermission() {
        Task { @MainActor in
            let authorization = await audioDeviceManager.requestPermission()
            microphoneStatusField.stringValue = authorization.title
            reloadAudioDevices()
            statusLabel.stringValue = "麦克风权限已更新"
        }
    }

    @objc func refreshAudioDevices() {
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

        setupSidebar(in: contentView)

        contentContainer.frame = NSRect(x: 228, y: 84, width: 576, height: 400)
        contentContainer.wantsLayer = true
        contentView.addSubview(contentContainer)

        statusLabel.frame = NSRect(x: 228, y: 36, width: 360, height: 24)
        statusLabel.textColor = .secondaryLabelColor
        contentView.addSubview(statusLabel)

        let saveButton = NSButton(title: "保存", target: self, action: #selector(save))
        saveButton.frame = NSRect(x: 724, y: 32, width: 80, height: 30)
        contentView.addSubview(saveButton)

        providerPopUp.addItems(withTitles: SpeechProvider.allCases.map(\.title))
        providerPopUp.target = self
        providerPopUp.action = #selector(changeProvider)
        speechModePopUp.addItems(withTitles: SpeechMode.allCases.map(\.title))
        speechModePopUp.target = self
        speechModePopUp.action = #selector(changeSpeechMode)
        // 源/目标语种下拉框按当前 provider 在 loadSettings/changeProvider 里动态填充
        sourceLanguagePopUp.target = self
        targetLanguagePopUp.target = self
        sourceLanguagePopUp.action = #selector(changeSpeechLanguage)
        targetLanguagePopUp.action = #selector(changeSpeechLanguage)
        speechModeDetailLabel.textColor = .secondaryLabelColor
        speechModeDetailLabel.lineBreakMode = .byTruncatingTail
        speechLanguageWarningLabel.textColor = .systemRed
        speechLanguageWarningLabel.lineBreakMode = .byWordWrapping
        speechLanguageWarningLabel.maximumNumberOfLines = 2
        setupAPIKeyControls()
        opacitySlider.target = self
        opacitySlider.action = #selector(changeOpacity)
        fontSizeSlider.target = self
        fontSizeSlider.action = #selector(changeFontSize)
        audioDevicePopUp.target = self
        audioDevicePopUp.action = #selector(selectAudioDevice)
        helperStatusField.lineBreakMode = .byTruncatingMiddle
    }

    private func loadSettings() {
        let settings = settingsStore.settings
        if let index = SpeechProvider.allCases.firstIndex(of: settings.speechProvider) {
            providerPopUp.selectItem(at: index)
        }
        if let index = SpeechMode.allCases.firstIndex(of: settings.speechMode) {
            speechModePopUp.selectItem(at: index)
        }
        reloadLanguagePopUps(sourceCode: settings.speechSourceLanguage, targetCode: settings.speechTargetLanguage)
        volcengineKeyDraft = settings.volcengineAPIKey
        azureKeyDraft = settings.azureSpeechKey
        lastSelectedProvider = settings.speechProvider
        regionField.stringValue = settings.azureSpeechRegion
        setAPIKey(currentProviderKeyDraft())
        opacitySlider.doubleValue = settings.overlayOpacity
        fontSizeSlider.doubleValue = settings.overlayFontSize
        helperStatusField.stringValue = currentDiagnostic(for: settings)
        microphoneStatusField.stringValue = audioDeviceManager.authorization.title
        reloadAudioDevices()
        updateOpacityLabel()
        updateFontSizeLabel()
        updateSpeechModeDetail()
        statusLabel.stringValue = ""
        renderSelectedSection()
    }

    private func renderSelectedSection() {
        updateSidebarSelection()
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

    func updateFontSizeLabel() {
        fontSizeValueLabel.stringValue = "\(Int(fontSizeSlider.doubleValue)) pt"
    }
}

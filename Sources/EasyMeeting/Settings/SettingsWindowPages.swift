import AppKit

@MainActor
extension SettingsWindowController {
    func appPage() -> NSView {
        let page = pageView(title: "程序")
        let group = groupView(y: 188, height: 148)
        page.addSubview(group)

        addRowTitle("悬浮窗透明度", to: group, y: 104)
        opacitySlider.frame = NSRect(x: 244, y: 100, width: 250, height: 24)
        opacityValueLabel.frame = NSRect(x: 508, y: 101, width: 72, height: 22)
        opacityValueLabel.textColor = .secondaryLabelColor
        group.addSubview(opacitySlider)
        group.addSubview(opacityValueLabel)
        addDivider(to: group, y: 74)

        addRowTitle("字幕字体大小", to: group, y: 36)
        fontSizeSlider.frame = NSRect(x: 244, y: 32, width: 250, height: 24)
        fontSizeValueLabel.frame = NSRect(x: 508, y: 33, width: 72, height: 22)
        fontSizeValueLabel.textColor = .secondaryLabelColor
        group.addSubview(fontSizeSlider)
        group.addSubview(fontSizeValueLabel)
        return page
    }

    func speechPage() -> NSView {
        let page = pageView(title: "语音")
        let serviceGroup = groupView(y: 232, height: 208)
        page.addSubview(serviceGroup)
        addRowTitle("语音服务", to: serviceGroup, y: 166)
        providerPopUp.frame = NSRect(x: 244, y: 162, width: 250, height: 28)
        serviceGroup.addSubview(providerPopUp)
        addDivider(to: serviceGroup, y: 146)

        addRowTitle("翻译预设", to: serviceGroup, y: 120)
        speechModePopUp.frame = NSRect(x: 244, y: 116, width: 250, height: 28)
        speechModeDetailLabel.frame = NSRect(x: 508, y: 120, width: 132, height: 22)
        serviceGroup.addSubview(speechModePopUp)
        serviceGroup.addSubview(speechModeDetailLabel)
        addDivider(to: serviceGroup, y: 100)

        addRowTitle("源语种", to: serviceGroup, y: 74)
        sourceLanguagePopUp.frame = NSRect(x: 244, y: 70, width: 250, height: 28)
        serviceGroup.addSubview(sourceLanguagePopUp)
        addDivider(to: serviceGroup, y: 54)

        addRowTitle("目标语种", to: serviceGroup, y: 28)
        targetLanguagePopUp.frame = NSRect(x: 244, y: 24, width: 250, height: 28)
        serviceGroup.addSubview(targetLanguagePopUp)
        speechLanguageWarningLabel.frame = NSRect(x: 244, y: 4, width: 390, height: 18)
        serviceGroup.addSubview(speechLanguageWarningLabel)

        let keyGroup = groupView(y: 72, height: 144)
        page.addSubview(keyGroup)
        addRowTitle("Resource ID", to: keyGroup, y: 102)
        resourceValueLabel.frame = NSRect(x: 244, y: 103, width: 350, height: 22)
        resourceValueLabel.textColor = .secondaryLabelColor
        keyGroup.addSubview(resourceValueLabel)
        addDivider(to: keyGroup, y: 74)

        addRowTitle("火山 API Key", to: keyGroup, y: 36)
        apiKeyField.frame = NSRect(x: 244, y: 34, width: 246, height: 24)
        apiKeyVisibleField.frame = apiKeyField.frame
        pasteAPIKeyButton.frame = NSRect(x: 500, y: 31, width: 50, height: 30)
        revealAPIKeyButton.frame = NSRect(x: 552, y: 31, width: 50, height: 30)
        clearAPIKeyButton.frame = NSRect(x: 604, y: 31, width: 50, height: 30)
        apiKeyLengthLabel.frame = NSRect(x: 244, y: 10, width: 220, height: 18)
        keyGroup.addSubview(apiKeyField)
        keyGroup.addSubview(apiKeyVisibleField)
        keyGroup.addSubview(pasteAPIKeyButton)
        keyGroup.addSubview(revealAPIKeyButton)
        keyGroup.addSubview(clearAPIKeyButton)
        keyGroup.addSubview(apiKeyLengthLabel)

        let helperGroup = groupView(y: -16, height: 72)
        page.addSubview(helperGroup)
        addRowTitle("本地 helper", to: helperGroup, y: 26)
        helperStatusField.frame = NSRect(x: 244, y: 27, width: 282, height: 22)
        helperStatusField.textColor = .secondaryLabelColor
        let checkButton = NSButton(title: "检查配置", target: self, action: #selector(checkConfiguration))
        checkButton.frame = NSRect(x: 544, y: 22, width: 92, height: 30)
        helperGroup.addSubview(helperStatusField)
        helperGroup.addSubview(checkButton)
        return page
    }

    func microphonePage() -> NSView {
        let page = pageView(title: "麦克风")
        let group = groupView(y: 180, height: 156)
        page.addSubview(group)

        addRowTitle("权限状态", to: group, y: 112)
        microphoneStatusField.frame = NSRect(x: 244, y: 113, width: 200, height: 22)
        microphoneStatusField.textColor = .secondaryLabelColor
        let permissionButton = NSButton(title: "请求权限", target: self, action: #selector(requestMicrophonePermission))
        permissionButton.frame = NSRect(x: 544, y: 108, width: 92, height: 30)
        group.addSubview(microphoneStatusField)
        group.addSubview(permissionButton)
        addDivider(to: group, y: 78)

        addRowTitle("输入设备", to: group, y: 38)
        audioDevicePopUp.frame = NSRect(x: 244, y: 34, width: 250, height: 28)
        let refreshButton = NSButton(title: "刷新设备", target: self, action: #selector(refreshAudioDevices))
        refreshButton.frame = NSRect(x: 544, y: 32, width: 92, height: 30)
        group.addSubview(audioDevicePopUp)
        group.addSubview(refreshButton)
        return page
    }

    func pageView(title: String) -> NSView {
        let page = SettingsBackgroundView(frame: contentContainer.bounds)
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .boldSystemFont(ofSize: 22)
        titleLabel.frame = NSRect(x: 0, y: 440, width: 240, height: 28)
        page.addSubview(titleLabel)
        return page
    }

    func groupView(y: CGFloat, height: CGFloat) -> NSView {
        let view = SettingsBackgroundView(frame: NSRect(x: 0, y: y, width: 660, height: height))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        view.layer?.cornerRadius = 10
        return view
    }

    @discardableResult
    func addRowTitle(_ title: String, to view: NSView, y: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.frame = NSRect(x: 18, y: y, width: 180, height: 22)
        view.addSubview(label)
        return label
    }

    func addDivider(to view: NSView, y: CGFloat) {
        let divider = NSBox(frame: NSRect(x: 18, y: y, width: 624, height: 1))
        divider.boxType = .separator
        view.addSubview(divider)
    }
}

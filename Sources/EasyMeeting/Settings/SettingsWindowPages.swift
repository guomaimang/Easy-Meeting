import AppKit

@MainActor
extension SettingsWindowController {
    func appPage() -> NSView {
        let page = pageView(title: "程序")
        let group = groupView(y: 196, height: 140)
        page.addSubview(group)

        addRowTitle("悬浮窗透明度", to: group, y: 98)
        opacitySlider.frame = NSRect(x: 220, y: 94, width: 230, height: 24)
        opacityValueLabel.frame = NSRect(x: 466, y: 95, width: 72, height: 22)
        opacityValueLabel.textColor = .secondaryLabelColor
        group.addSubview(opacitySlider)
        group.addSubview(opacityValueLabel)
        addDivider(to: group, y: 70)

        addRowTitle("字幕字体大小", to: group, y: 32)
        fontSizeSlider.frame = NSRect(x: 220, y: 28, width: 230, height: 24)
        fontSizeValueLabel.frame = NSRect(x: 466, y: 29, width: 72, height: 22)
        fontSizeValueLabel.textColor = .secondaryLabelColor
        group.addSubview(fontSizeSlider)
        group.addSubview(fontSizeValueLabel)

        // 退出程序分组：放在"程序"页底部，点击后弹二次确认。
        let quitGroup = groupView(y: 120, height: 60)
        page.addSubview(quitGroup)
        addRowTitle("退出程序", to: quitGroup, y: 18)
        let quitButton = NSButton(
            title: "退出 Easy Meeting",
            target: self,
            action: #selector(quitApplication)
        )
        quitButton.bezelColor = .systemRed
        quitButton.frame = NSRect(x: 410, y: 14, width: 148, height: 30)
        quitGroup.addSubview(quitButton)
        return page
    }

    /// 退出按钮回调：弹出系统级 NSAlert 进行二次确认，默认按钮为"取消"以防误触；
    /// 用户确认后调用 `NSApp.terminate(nil)` 走标准退出流程，AppDelegate 中的
    /// 清理逻辑（停录音、关闭悬浮窗等）会在 applicationWillTerminate 时执行。
    @objc func quitApplication() {
        let alert = NSAlert()
        alert.messageText = "确认退出 Easy Meeting？"
        alert.informativeText = "退出后会停止当前录音与翻译，并关闭悬浮窗。"
        alert.alertStyle = .warning
        // 顺序决定默认/取消按钮：第一个按钮是"退出"，第二个按钮设为默认（回车=取消），
        // 这样按回车不会误退出，必须显式点击"退出"或选中后再回车。
        let quitAction = alert.addButton(withTitle: "退出")
        let cancelAction = alert.addButton(withTitle: "取消")
        quitAction.keyEquivalent = ""
        cancelAction.keyEquivalent = "\r"

        let handleResponse: (NSApplication.ModalResponse) -> Void = { response in
            if response == .alertFirstButtonReturn {
                NSApp.terminate(nil)
            }
        }

        if let window {
            alert.beginSheetModal(for: window, completionHandler: handleResponse)
        } else {
            handleResponse(alert.runModal())
        }
    }


    func speechPage() -> NSView {
        let page = pageView(title: "语音")
        let serviceGroup = groupView(y: 158, height: 208)
        page.addSubview(serviceGroup)
        addRowTitle("语音服务", to: serviceGroup, y: 166)
        providerPopUp.frame = NSRect(x: 220, y: 162, width: 230, height: 28)
        serviceGroup.addSubview(providerPopUp)
        addDivider(to: serviceGroup, y: 146)

        addRowTitle("翻译预设", to: serviceGroup, y: 120)
        speechModePopUp.frame = NSRect(x: 220, y: 116, width: 230, height: 28)
        speechModeDetailLabel.frame = NSRect(x: 466, y: 120, width: 88, height: 22)
        serviceGroup.addSubview(speechModePopUp)
        serviceGroup.addSubview(speechModeDetailLabel)
        addDivider(to: serviceGroup, y: 100)

        addRowTitle("源语种", to: serviceGroup, y: 74)
        sourceLanguagePopUp.frame = NSRect(x: 220, y: 70, width: 230, height: 28)
        serviceGroup.addSubview(sourceLanguagePopUp)
        addDivider(to: serviceGroup, y: 54)

        addRowTitle("目标语种", to: serviceGroup, y: 28)
        targetLanguagePopUp.frame = NSRect(x: 220, y: 24, width: 230, height: 28)
        serviceGroup.addSubview(targetLanguagePopUp)
        speechLanguageWarningLabel.frame = NSRect(x: 220, y: 4, width: 330, height: 18)
        serviceGroup.addSubview(speechLanguageWarningLabel)

        let keyGroup = groupView(y: 44, height: 102)
        page.addSubview(keyGroup)
        if selectedSection == .speech, providerPopUp.indexOfSelectedItem == SpeechProvider.allCases.firstIndex(of: .azure) {
            buildAzureKeyGroup(keyGroup)
        } else {
            buildVolcengineKeyGroup(keyGroup)
        }

        let helperGroup = groupView(y: 0, height: 40)
        page.addSubview(helperGroup)
        addRowTitle("本地 helper", to: helperGroup, y: 10)
        helperStatusField.frame = NSRect(x: 220, y: 11, width: 230, height: 22)
        helperStatusField.textColor = .secondaryLabelColor
        let checkButton = NSButton(title: "检查配置", target: self, action: #selector(checkConfiguration))
        checkButton.frame = NSRect(x: 466, y: 6, width: 92, height: 30)
        helperGroup.addSubview(helperStatusField)
        helperGroup.addSubview(checkButton)
        return page
    }

    /// 火山密钥分组：固定 Resource ID + 火山 API Key。
    private func buildVolcengineKeyGroup(_ keyGroup: NSView) {
        addRowTitle("Resource ID", to: keyGroup, y: 74)
        resourceValueLabel.frame = NSRect(x: 220, y: 75, width: 330, height: 22)
        resourceValueLabel.textColor = .secondaryLabelColor
        keyGroup.addSubview(resourceValueLabel)
        addDivider(to: keyGroup, y: 54)

        apiKeyRowTitle.stringValue = "火山 API Key"
        addKeyRow(to: keyGroup)
    }

    /// Azure 密钥分组：区域 + Azure 语音密钥。
    private func buildAzureKeyGroup(_ keyGroup: NSView) {
        addRowTitle("区域 Region", to: keyGroup, y: 74)
        regionField.frame = NSRect(x: 220, y: 73, width: 230, height: 24)
        regionField.placeholderString = AppSettings.defaults.azureSpeechRegion
        regionField.delegate = self
        keyGroup.addSubview(regionField)
        addDivider(to: keyGroup, y: 54)

        apiKeyRowTitle.stringValue = "Azure 语音密钥"
        addKeyRow(to: keyGroup)
    }

    /// 复用同一套密钥输入控件（明/密文 + 粘贴/显示/清空 + 长度提示）。
    private func addKeyRow(to keyGroup: NSView) {
        addRowTitleControl(apiKeyRowTitle, to: keyGroup, y: 20)
        apiKeyField.frame = NSRect(x: 220, y: 18, width: 190, height: 24)
        apiKeyVisibleField.frame = apiKeyField.frame
        pasteAPIKeyButton.frame = NSRect(x: 418, y: 15, width: 44, height: 30)
        revealAPIKeyButton.frame = NSRect(x: 466, y: 15, width: 44, height: 30)
        clearAPIKeyButton.frame = NSRect(x: 514, y: 15, width: 44, height: 30)
        apiKeyLengthLabel.frame = NSRect(x: 220, y: 0, width: 220, height: 18)
        keyGroup.addSubview(apiKeyField)
        keyGroup.addSubview(apiKeyVisibleField)
        keyGroup.addSubview(pasteAPIKeyButton)
        keyGroup.addSubview(revealAPIKeyButton)
        keyGroup.addSubview(clearAPIKeyButton)
        keyGroup.addSubview(apiKeyLengthLabel)
    }

    func microphonePage() -> NSView {
        let page = pageView(title: "麦克风")
        let group = groupView(y: 186, height: 150)
        page.addSubview(group)

        addRowTitle("权限状态", to: group, y: 108)
        microphoneStatusField.frame = NSRect(x: 220, y: 109, width: 200, height: 22)
        microphoneStatusField.textColor = .secondaryLabelColor
        let permissionButton = NSButton(title: "请求权限", target: self, action: #selector(requestMicrophonePermission))
        permissionButton.frame = NSRect(x: 466, y: 104, width: 92, height: 30)
        group.addSubview(microphoneStatusField)
        group.addSubview(permissionButton)
        addDivider(to: group, y: 74)

        addRowTitle("输入设备", to: group, y: 34)
        audioDevicePopUp.frame = NSRect(x: 220, y: 30, width: 230, height: 28)
        let refreshButton = NSButton(title: "刷新设备", target: self, action: #selector(refreshAudioDevices))
        refreshButton.frame = NSRect(x: 466, y: 28, width: 92, height: 30)
        group.addSubview(audioDevicePopUp)
        group.addSubview(refreshButton)
        return page
    }

    func pageView(title: String) -> NSView {
        let page = SettingsBackgroundView(frame: contentContainer.bounds)
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .boldSystemFont(ofSize: 22)
        titleLabel.frame = NSRect(x: 0, y: 360, width: 240, height: 28)
        page.addSubview(titleLabel)
        return page
    }

    func groupView(y: CGFloat, height: CGFloat) -> NSView {
        let view = SettingsBackgroundView(frame: NSRect(x: 0, y: y, width: 576, height: height))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.78).cgColor
        view.layer?.cornerRadius = 8
        return view
    }

    @discardableResult
    func addRowTitle(_ title: String, to view: NSView, y: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.frame = NSRect(x: 18, y: y, width: 170, height: 22)
        view.addSubview(label)
        return label
    }

    /// 复用已有的标题 label（文本随 provider 切换变化）。
    func addRowTitleControl(_ label: NSTextField, to view: NSView, y: CGFloat) {
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.frame = NSRect(x: 18, y: y, width: 170, height: 22)
        view.addSubview(label)
    }

    func addDivider(to view: NSView, y: CGFloat) {
        let divider = NSBox(frame: NSRect(x: 18, y: y, width: 540, height: 1))
        divider.boxType = .separator
        view.addSubview(divider)
    }
}

import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let overlayController: OverlayWindowController
    private let audioDeviceManager: AudioDeviceManager
    private let meetingStore: MeetingStore
    private let meetingSessionController: MeetingSessionController
    private let settingsStore: AppSettingsStore
    private let settingsWindowController: SettingsWindowController

    init(
        overlayController: OverlayWindowController,
        audioDeviceManager: AudioDeviceManager,
        meetingStore: MeetingStore,
        meetingSessionController: MeetingSessionController,
        settingsStore: AppSettingsStore,
        settingsWindowController: SettingsWindowController
    ) {
        self.overlayController = overlayController
        self.audioDeviceManager = audioDeviceManager
        self.meetingStore = meetingStore
        self.meetingSessionController = meetingSessionController
        self.settingsStore = settingsStore
        self.settingsWindowController = settingsWindowController
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        setupStatusItem()
    }

    @objc private func showOverlay() {
        overlayController.showReadyStatus()
    }

    @objc private func toggleOverlay() {
        overlayController.toggleVisibility()
    }

    @objc private func setOpacityLow() {
        saveOpacity(0.45)
    }

    @objc private func setOpacityMedium() {
        saveOpacity(0.72)
    }

    @objc private func setOpacityHigh() {
        saveOpacity(0.9)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func openSettings() {
        settingsWindowController.show()
    }

    @objc private func requestMicrophonePermission() {
        Task { @MainActor in
            let authorization = await audioDeviceManager.requestPermission()
            overlayController.showStatus(
                source: authorization.title,
                translation: "当前麦克风：\(audioDeviceManager.selectedDeviceName())"
            )
            rebuildMenu()
        }
    }

    @objc private func refreshAudioDevices() {
        audioDeviceManager.refreshDevices()
        overlayController.showStatus(
            source: audioDeviceManager.authorization.title,
            translation: "当前麦克风：\(audioDeviceManager.selectedDeviceName())"
        )
        rebuildMenu()
    }

    @objc private func selectAudioDevice(_ sender: NSMenuItem) {
        guard let deviceID = sender.representedObject as? String else { return }
        audioDeviceManager.selectDevice(id: deviceID)
        overlayController.showStatus(
            source: "已选择麦克风",
            translation: audioDeviceManager.selectedDeviceName()
        )
        rebuildMenu()
    }

    @objc private func toggleRecording() {
        if meetingSessionController.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    @objc private func selectSpeechMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = SpeechMode(rawValue: rawValue) else {
            return
        }
        var settings = settingsStore.settings
        settings.speechMode = mode
        settings.speechSourceLanguage = mode.configuration.sourceLanguage
        settings.speechTargetLanguage = mode.configuration.targetLanguage
        do {
            try settingsStore.save(settings)
            overlayController.showStatus(source: "已切换翻译模式", translation: "\(mode.title)：\(mode.detail)")
        } catch {
            overlayController.showStatus(source: "翻译模式保存失败", translation: error.localizedDescription)
        }
        rebuildMenu()
    }

    @objc private func exportMeeting(_ sender: NSMenuItem) {
        guard let meeting = sender.representedObject as? StoredMeetingSummary else { return }

        do {
            let urls = try meetingStore.exportMeeting(meeting)
            overlayController.showStatus(source: "导出完成：\(urls.count) 个文件", translation: meeting.directoryPath)
        } catch {
            overlayController.showStatus(source: "导出失败", translation: error.localizedDescription)
        }
    }

    private func setupStatusItem() {
        statusItem.button?.title = "Easy Meeting"
        statusItem.button?.toolTip = "Easy Meeting 会议助手"
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "显示悬浮窗", action: #selector(showOverlay), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "显示/隐藏悬浮窗", action: #selector(toggleOverlay), keyEquivalent: "h"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(recordingMenuItem())
        menu.addItem(NSMenuItem.separator())
        menu.addItem(speechModeMenuItem())
        menu.addItem(NSMenuItem.separator())
        menu.addItem(audioMenuItem())
        menu.addItem(NSMenuItem.separator())
        menu.addItem(historyMenuItem())
        menu.addItem(NSMenuItem.separator())
        menu.addItem(opacityMenuItem())
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    private func audioMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "麦克风", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        submenu.addItem(NSMenuItem(
            title: audioDeviceManager.authorization.title,
            action: #selector(requestMicrophonePermission),
            keyEquivalent: ""
        ))
        submenu.addItem(NSMenuItem(title: "刷新输入设备", action: #selector(refreshAudioDevices), keyEquivalent: ""))
        submenu.addItem(NSMenuItem.separator())

        if audioDeviceManager.devices.isEmpty {
            let emptyItem = NSMenuItem(title: "没有发现输入设备", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            submenu.addItem(emptyItem)
        } else {
            audioDeviceManager.devices.forEach { device in
                let title = device.isDefault ? "\(device.name)（系统默认）" : device.name
                let deviceItem = NSMenuItem(title: title, action: #selector(selectAudioDevice), keyEquivalent: "")
                deviceItem.representedObject = device.id
                deviceItem.state = device.id == audioDeviceManager.selectedDeviceID ? .on : .off
                submenu.addItem(deviceItem)
            }
        }

        submenu.items.forEach { $0.target = self }
        item.submenu = submenu
        return item
    }

    private func historyMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "最近会议", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        do {
            let meetings = try meetingStore.recentMeetings()
            if meetings.isEmpty {
                let emptyItem = NSMenuItem(title: "暂无会议记录", action: nil, keyEquivalent: "")
                emptyItem.isEnabled = false
                submenu.addItem(emptyItem)
            } else {
                meetings.forEach { meeting in
                    let menuItem = NSMenuItem(
                        title: "\(meeting.startedAt)  \(meeting.title)",
                        action: #selector(exportMeeting),
                        keyEquivalent: ""
                    )
                    menuItem.representedObject = meeting
                    submenu.addItem(menuItem)
                }
            }
        } catch {
            let errorItem = NSMenuItem(title: "读取历史失败", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            submenu.addItem(errorItem)
        }

        submenu.items.forEach { $0.target = self }
        item.submenu = submenu
        return item
    }

    private func recordingMenuItem() -> NSMenuItem {
        let title = meetingSessionController.isRecording ? "停止录音" : "开始录音"
        return NSMenuItem(title: title, action: #selector(toggleRecording), keyEquivalent: "r")
    }

    private func speechModeMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "翻译模式", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        SpeechMode.allCases.forEach { mode in
            let modeItem = NSMenuItem(title: mode.title, action: #selector(selectSpeechMode), keyEquivalent: "")
            modeItem.representedObject = mode.rawValue
            let configuration = settingsStore.settings.speechConfiguration
            modeItem.state = mode.configuration.sourceLanguage == configuration.sourceLanguage &&
                mode.configuration.targetLanguage == configuration.targetLanguage ? .on : .off
            submenu.addItem(modeItem)
        }

        submenu.items.forEach { $0.target = self }
        item.submenu = submenu
        return item
    }

    private func opacityMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "悬浮窗透明度", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        submenu.addItem(NSMenuItem(title: "低", action: #selector(setOpacityLow), keyEquivalent: ""))
        submenu.addItem(NSMenuItem(title: "中", action: #selector(setOpacityMedium), keyEquivalent: ""))
        submenu.addItem(NSMenuItem(title: "高", action: #selector(setOpacityHigh), keyEquivalent: ""))
        submenu.items.forEach { $0.target = self }

        item.submenu = submenu
        return item
    }

    private func startRecording() {
        meetingSessionController.start { [weak self] source, translation in
            self?.overlayController.showStatus(source: source, translation: translation)
        } onMenuUpdate: { [weak self] in
            self?.rebuildMenu()
        }
    }

    private func stopRecording() {
        meetingSessionController.stop { [weak self] source, translation in
            self?.overlayController.showStatus(source: source, translation: translation)
        } onMenuUpdate: { [weak self] in
            self?.rebuildMenu()
        }
    }

    private func saveOpacity(_ opacity: Double) {
        overlayController.setOpacity(CGFloat(opacity))
        do {
            try settingsStore.saveOverlayOpacity(opacity)
        } catch {
            overlayController.showStatus(source: "透明度保存失败", translation: error.localizedDescription)
        }
    }
}

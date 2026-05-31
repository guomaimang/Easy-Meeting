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
        self.statusItem = NSStatusBar.system.statusItem(withLength: 34)
        super.init()
        overlayController.onToggleRecording = { [weak self] in
            self?.toggleRecording()
        }
        overlayController.onSelectDevice = { [weak self] deviceID in
            self?.switchMicrophone(to: deviceID)
        }
        overlayController.onOpacityChange = { [weak self] opacity in
            self?.persistOpacity(opacity)
        }
        setupStatusItem()
    }

    @objc private func showOverlay() {
        overlayController.showReadyStatus()
    }

    @objc private func toggleOverlay() {
        overlayController.toggleVisibility()
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
        switchMicrophone(to: deviceID)
    }

    /// 切换麦克风的统一入口：菜单栏麦克风项与悬浮窗下拉共用。
    /// 录音中走热切换（识别与字幕不中断），未录音仅记录选择。
    private func switchMicrophone(to deviceID: String) {
        meetingSessionController.switchMicrophone(to: deviceID) { [weak self] source, translation in
            self?.overlayController.showStatus(source: source, translation: translation)
        }
        rebuildMenu()
    }

    @objc private func toggleRecording() {
        switch meetingSessionController.recordingState {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .starting:
            overlayController.showStatus(source: "正在启动录音", translation: "请稍候，当前启动流程完成后即可停止。")
        case .stopping:
            overlayController.showStatus(source: "正在停止录音", translation: "请稍候，保存完成后即可再次开始。")
        }
    }

    @objc private func selectSpeechMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = SpeechMode(rawValue: rawValue) else {
            return
        }
        var settings = settingsStore.settings
        let provider = settings.speechProvider
        let configuration = mode.configuration(for: provider)
        settings.speechMode = mode
        settings.speechSourceLanguage = configuration.sourceCode
        settings.speechTargetLanguage = configuration.targetCode
        do {
            try settingsStore.save(settings)
            overlayController.showStatus(source: "已切换翻译模式", translation: "\(mode.title)：\(configuration.detail)")
        } catch {
            overlayController.showStatus(source: "翻译模式保存失败", translation: error.localizedDescription)
        }
        rebuildMenu()
    }

    @objc private func openMeetingsFolder() {
        do {
            let url = try AppStorage.meetingsURL()
            NSWorkspace.shared.open(url)
        } catch {
            overlayController.showStatus(source: "打开会议文件夹失败", translation: error.localizedDescription)
        }
    }

    private func setupStatusItem() {
        statusItem.button?.title = "EM"
        statusItem.button?.toolTip = "Easy Meeting 会议助手"
        statusItem.button?.font = .systemFont(ofSize: 13, weight: .semibold)
        statusItem.button?.isEnabled = true
        NSLog("菜单栏状态项已创建：EM")
        rebuildMenu()
    }

    private func rebuildMenu() {
        overlayController.setRecording(meetingSessionController.recordingState.isRecordingVisible)
        overlayController.updateDevices(
            audioDeviceManager.devices,
            selectedID: audioDeviceManager.selectedDeviceID
        )
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
        menu.addItem(NSMenuItem(title: "最近会议", action: #selector(openMeetingsFolder), keyEquivalent: ""))
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

    private func recordingMenuItem() -> NSMenuItem {
        let item: NSMenuItem
        switch meetingSessionController.recordingState {
        case .idle:
            item = NSMenuItem(title: "开始录音", action: #selector(toggleRecording), keyEquivalent: "r")
        case .starting:
            item = NSMenuItem(title: "正在启动录音…", action: #selector(toggleRecording), keyEquivalent: "r")
        case .recording:
            item = NSMenuItem(title: "停止录音", action: #selector(toggleRecording), keyEquivalent: "r")
        case .stopping:
            item = NSMenuItem(title: "正在停止录音…", action: #selector(toggleRecording), keyEquivalent: "r")
        }
        return item
    }

    private func speechModeMenuItem() -> NSMenuItem {
        let settings = settingsStore.settings
        let item = NSMenuItem(title: "翻译模式", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let presets = SpeechMode.presets(for: settings.speechProvider)

        presets.forEach { mode in
            let modeItem = NSMenuItem(title: mode.title, action: #selector(selectSpeechMode), keyEquivalent: "")
            modeItem.representedObject = mode.rawValue
            let configuration = settings.speechConfiguration
            let presetConfiguration = mode.configuration(for: settings.speechProvider)
            modeItem.state = presetConfiguration.sourceCode == configuration.sourceCode &&
                presetConfiguration.targetCode == configuration.targetCode ? .on : .off
            submenu.addItem(modeItem)
        }

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

    /// 快捷键已即时调整透明度，这里只负责写入存储，避免重复设置悬浮窗。
    private func persistOpacity(_ opacity: Double) {
        do {
            try settingsStore.saveOverlayOpacity(opacity)
        } catch {
            overlayController.showStatus(source: "透明度保存失败", translation: error.localizedDescription)
        }
    }
}

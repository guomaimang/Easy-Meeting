import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayController: OverlayWindowController?
    private var statusBarController: StatusBarController?
    private var audioDeviceManager: AudioDeviceManager?
    private var audioRecorder: AudioRecorder?
    private var meetingStore: MeetingStore?
    private var meetingSessionController: MeetingSessionController?
    private var settingsStore: AppSettingsStore?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()

        let audioDeviceManager = AudioDeviceManager()
        let audioRecorder = AudioRecorder()
        let meetingStore = MeetingStore()
        let settingsStore = AppSettingsStore()
        let meetingSessionController = MeetingSessionController(
            audioDeviceManager: audioDeviceManager,
            audioRecorder: audioRecorder,
            meetingStore: meetingStore,
            settingsStore: settingsStore
        )
        let overlayController = OverlayWindowController(settings: settingsStore.settings)
        let settingsWindowController = SettingsWindowController(
            settingsStore: settingsStore,
            audioDeviceManager: audioDeviceManager,
            overlayController: overlayController
        )
        let statusBarController = StatusBarController(
            overlayController: overlayController,
            audioDeviceManager: audioDeviceManager,
            meetingStore: meetingStore,
            meetingSessionController: meetingSessionController,
            settingsStore: settingsStore,
            settingsWindowController: settingsWindowController
        )

        self.audioDeviceManager = audioDeviceManager
        self.audioRecorder = audioRecorder
        self.meetingStore = meetingStore
        self.meetingSessionController = meetingSessionController
        self.settingsStore = settingsStore
        self.settingsWindowController = settingsWindowController
        self.overlayController = overlayController
        self.statusBarController = statusBarController

        overlayController.show()
        presentInitialConfigurationIfNeeded(
            settingsStore: settingsStore,
            settingsWindowController: settingsWindowController,
            overlayController: overlayController
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 正常退出路径的兜底：确保停掉语音 helper 子进程，不留孤儿。
        meetingSessionController?.shutdownForAppTermination()
    }

    @MainActor
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Easy Meeting")
        appMenu.addItem(NSMenuItem(
            title: "退出 Easy Meeting",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(NSMenuItem(title: "撤销", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "重做", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @MainActor
    private func presentInitialConfigurationIfNeeded(
        settingsStore: AppSettingsStore,
        settingsWindowController: SettingsWindowController,
        overlayController: OverlayWindowController
    ) {
        let diagnostic = VolcengineHelperRuntime.diagnostic(settings: settingsStore.settings)
        guard diagnostic.hasPrefix("配置可用") == false else { return }

        overlayController.showStatus(
            source: "请先完成 Easy Meeting 设置",
            translation: "顶部菜单栏点击 Easy Meeting，或在已打开的设置窗口填写火山配置。"
        )
        settingsWindowController.show()
    }
}

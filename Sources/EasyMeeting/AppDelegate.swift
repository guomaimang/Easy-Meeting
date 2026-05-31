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
        let overlayController = OverlayWindowController(initialOpacity: settingsStore.settings.overlayOpacity)
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

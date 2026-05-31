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
        let settingsWindowController = SettingsWindowController(settingsStore: settingsStore)
        let meetingSessionController = MeetingSessionController(
            audioDeviceManager: audioDeviceManager,
            audioRecorder: audioRecorder,
            meetingStore: meetingStore,
            settingsStore: settingsStore
        )
        let overlayController = OverlayWindowController()
        let statusBarController = StatusBarController(
            overlayController: overlayController,
            audioDeviceManager: audioDeviceManager,
            meetingStore: meetingStore,
            meetingSessionController: meetingSessionController,
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
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

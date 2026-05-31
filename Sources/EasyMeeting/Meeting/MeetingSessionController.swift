import Foundation

@MainActor
final class MeetingSessionController {
    private let audioDeviceManager: AudioDeviceManager
    private let audioRecorder: AudioRecorder
    private let meetingStore: MeetingStore
    private let settingsStore: AppSettingsStore
    private var speechClient: SpeechClient?

    var speechMode: SpeechMode = .englishToChinese

    var isRecording: Bool {
        audioRecorder.isRecording
    }

    init(
        audioDeviceManager: AudioDeviceManager,
        audioRecorder: AudioRecorder,
        meetingStore: MeetingStore,
        settingsStore: AppSettingsStore
    ) {
        self.audioDeviceManager = audioDeviceManager
        self.audioRecorder = audioRecorder
        self.meetingStore = meetingStore
        self.settingsStore = settingsStore
    }

    func start(onStatus: @escaping @MainActor (String, String) -> Void, onMenuUpdate: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            do {
                _ = await audioDeviceManager.requestPermission()
                guard audioDeviceManager.authorization == .authorized else {
                    throw AudioRecordingError.permissionDenied
                }

                let meeting = try meetingStore.startMeeting(mode: speechMode)
                try audioRecorder.startRecording(
                    to: meeting.audioURL,
                    selectedDeviceID: audioDeviceManager.selectedDeviceID
                )
                startSpeech(for: meeting, onStatus: onStatus)
                onStatus(
                    "正在录音：\(audioDeviceManager.selectedDeviceName())",
                    "\(speechMode.title)：音频保存到 \(meeting.audioURL.lastPathComponent)"
                )
            } catch {
                onStatus("录音启动失败", error.localizedDescription)
            }

            onMenuUpdate()
        }
    }

    func stop(onStatus: @escaping @MainActor (String, String) -> Void, onMenuUpdate: @escaping @MainActor () -> Void) {
        speechClient?.stop()
        audioRecorder.stopRecording { [weak self] result in
            Task { @MainActor in
                guard let self else { return }

                switch result {
                case .success:
                    self.finishMeeting(onStatus: onStatus)
                case let .failure(error):
                    onStatus("停止录音失败", error.localizedDescription)
                }

                onMenuUpdate()
            }
        }
    }

    private func startSpeech(
        for meeting: MeetingRecord,
        onStatus: @escaping @MainActor (String, String) -> Void
    ) {
        let client = SpeechClientFactory.make(settings: settingsStore.settings)
        speechClient = client
        client.start(mode: speechMode, meetingID: meeting.id) { [weak self] event in
            guard let self else { return }

            do {
                try meetingStore.addTranscriptSegment(from: event)
                onStatus(event.sourceText, event.translatedText)
            } catch {
                onStatus("转录写入失败", error.localizedDescription)
            }
        }
    }

    private func finishMeeting(onStatus: @escaping @MainActor (String, String) -> Void) {
        do {
            let meeting = try meetingStore.finishCurrentMeeting()
            onStatus("录音已保存", meeting?.directoryURL.path ?? "会议目录已更新")
        } catch {
            onStatus("会议保存失败", error.localizedDescription)
        }
    }
}

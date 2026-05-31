import Foundation

@MainActor
final class MeetingSessionController {
    enum RecordingState {
        case idle
        case starting
        case recording
        case stopping

        var isRecordingVisible: Bool {
            self == .recording || self == .stopping
        }
    }

    private static let autoStopInterval: TimeInterval = 4 * 60 * 60
    private let audioDeviceManager: AudioDeviceManager
    private let audioRecorder: AudioRecorder
    private let meetingStore: MeetingStore
    private let settingsStore: AppSettingsStore
    private var speechClient: SpeechClient?
    private var subtitleDisplay = SubtitleDisplayBuffer()
    private var lastStoredTranscriptKey: String?
    private var autoStopTimer: Timer?
    private(set) var recordingState: RecordingState = .idle

    var speechMode: SpeechMode {
        settingsStore.settings.speechMode
    }

    var isRecording: Bool {
        recordingState == .recording
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
        guard recordingState == .idle else {
            onStatus("录音操作进行中", recordingState == .stopping ? "正在停止录音，请稍后再开始。" : "正在启动录音，请稍候。")
            return
        }

        recordingState = .starting
        subtitleDisplay.reset()
        lastStoredTranscriptKey = nil
        cancelAutoStopTimer()
        onMenuUpdate()

        Task { @MainActor in
            do {
                _ = await audioDeviceManager.requestPermission()
                guard audioDeviceManager.authorization == .authorized else {
                    throw AudioRecordingError.permissionDenied
                }

                let configuration = settingsStore.settings.speechConfiguration
                let mode = settingsStore.settings.speechMode
                let meeting = try meetingStore.startMeeting(mode: mode)
                let client = startSpeech(for: meeting, onStatus: onStatus)
                try audioRecorder.startRecording(
                    to: meeting.audioURL,
                    selectedDeviceID: audioDeviceManager.selectedDeviceID
                )
                audioRecorder.onAudioFrame = { frame in
                    Task { @MainActor in
                        client.sendAudioFrame(frame)
                    }
                }
                recordingState = .recording
                scheduleAutoStop(onStatus: onStatus, onMenuUpdate: onMenuUpdate)
                onStatus(
                    "正在录音：\(audioDeviceManager.selectedDeviceName())",
                    "\(configuration.title)：4 小时后自动结束，音频保存到 \(meeting.audioURL.lastPathComponent)"
                )
            } catch {
                speechClient?.stop()
                speechClient = nil
                recordingState = .idle
                onStatus("录音启动失败", error.localizedDescription)
            }

            onMenuUpdate()
        }
    }

    func stop(onStatus: @escaping @MainActor (String, String) -> Void, onMenuUpdate: @escaping @MainActor () -> Void) {
        guard recordingState == .recording else {
            onStatus("录音操作进行中", recordingState == .starting ? "正在启动录音，请稍后再停止。" : "正在停止录音，请稍候。")
            return
        }

        recordingState = .stopping
        cancelAutoStopTimer()
        speechClient?.stop()
        speechClient = nil
        onMenuUpdate()

        audioRecorder.stopRecording { [weak self] result in
            Task { @MainActor in
                guard let self else { return }

                switch result {
                case .success:
                    self.finishMeeting(onStatus: onStatus)
                case let .failure(error):
                    onStatus("停止录音失败", error.localizedDescription)
                }

                self.recordingState = .idle
                onMenuUpdate()
            }
        }
    }

    private func scheduleAutoStop(
        onStatus: @escaping @MainActor (String, String) -> Void,
        onMenuUpdate: @escaping @MainActor () -> Void
    ) {
        autoStopTimer = Timer.scheduledTimer(withTimeInterval: Self.autoStopInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isRecording else { return }
                onStatus("会议已达到 4 小时上限", "正在自动停止录音并保存会议文件。")
                self.stop(onStatus: onStatus, onMenuUpdate: onMenuUpdate)
            }
        }
    }

    private func cancelAutoStopTimer() {
        autoStopTimer?.invalidate()
        autoStopTimer = nil
    }

    private func startSpeech(
        for meeting: MeetingRecord,
        onStatus: @escaping @MainActor (String, String) -> Void
    ) -> SpeechClient {
        let client = SpeechClientFactory.make(settings: settingsStore.settings)
        speechClient = client
        client.start(configuration: settingsStore.settings.speechConfiguration, meetingID: meeting.id) { [weak self] event in
            guard let self else { return }

            guard event.kind != .system else {
                onStatus(event.sourceText, event.translatedText)
                return
            }

            let display = subtitleDisplay.apply(event)
            onStatus(display.source, display.translation)

            guard event.kind == .translationFinal,
                  event.translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                return
            }
            let transcriptKey = Self.transcriptKey(for: event)
            guard transcriptKey != lastStoredTranscriptKey else {
                return
            }
            lastStoredTranscriptKey = transcriptKey

            do {
                try meetingStore.addTranscriptSegment(from: event)
            } catch {
                onStatus("转录写入失败", error.localizedDescription)
            }
        }
        return client
    }

    private func finishMeeting(onStatus: @escaping @MainActor (String, String) -> Void) {
        do {
            let meeting = try meetingStore.finishCurrentMeeting()
            guard let meeting else {
                onStatus("录音已保存", "会议目录已更新")
                return
            }

            do {
                let urls = try meetingStore.exportTranscriptMarkdown(for: meeting)
                let fileNames = urls.map { $0.lastPathComponent }.joined(separator: "、")
                onStatus("录音已保存，已导出：\(fileNames)", meeting.directoryURL.path)
            } catch {
                onStatus("录音已保存，markdown 导出失败", error.localizedDescription)
            }
        } catch {
            onStatus("会议保存失败", error.localizedDescription)
        }
    }

    private static func transcriptKey(for event: RealtimeSpeechEvent) -> String {
        [
            event.sourceText.normalizedSubtitleText,
            event.translatedText.normalizedSubtitleText,
            event.sourceLanguage,
            event.targetLanguage
        ].joined(separator: "\u{1F}")
    }
}

private extension String {
    var normalizedSubtitleText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }
}

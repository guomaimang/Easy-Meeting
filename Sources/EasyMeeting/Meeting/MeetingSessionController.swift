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
                    NSLog("[会议停止] audioRecorder.stopRecording 返回失败：%@", error.localizedDescription)
                    onStatus("停止录音失败", error.localizedDescription)
                }

                self.recordingState = .idle
                onMenuUpdate()
            }
        }
    }

    /// 切换麦克风。录音中走热切换：替换采集设备但不重建识别会话、不动录音文件与字幕缓冲，
    /// 字幕与转录连续不断（详见 docs/audio-hot-swap.md）；未录音时仅记录选择，下次开始录音生效。
    func switchMicrophone(
        to deviceID: String,
        onStatus: @escaping @MainActor (String, String) -> Void
    ) {
        let previousDeviceID = audioDeviceManager.selectedDeviceID
        audioDeviceManager.selectDevice(id: deviceID)
        let deviceName = audioDeviceManager.selectedDeviceName()

        guard recordingState == .recording else {
            onStatus("已选择麦克风", deviceName)
            return
        }

        audioRecorder.switchDevice(to: deviceID) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    onStatus("已切换麦克风：\(deviceName)", "识别与录音未中断")
                case let .failure(error):
                    // 热切换失败，录音仍在旧设备上继续，回滚选中项保持一致。
                    if let previousDeviceID {
                        self?.audioDeviceManager.selectDevice(id: previousDeviceID)
                    }
                    NSLog("[会议切麦] audioRecorder.switchDevice 失败：%@", error.localizedDescription)
                    onStatus("切换麦克风失败", "已保持当前麦克风继续录音：\(error.localizedDescription)")
                }
            }
        }
    }

    /// App 退出时的兜底清理：无视录音状态，立即停掉语音 helper，
    /// 避免主进程消失后留下残留的 helper 子进程。详见 docs/azure-speech.md。
    func shutdownForAppTermination() {
        cancelAutoStopTimer()
        speechClient?.stop()
        speechClient = nil
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

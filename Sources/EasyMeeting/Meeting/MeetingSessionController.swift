import Foundation

@MainActor
final class MeetingSessionController {
    private let audioDeviceManager: AudioDeviceManager
    private let audioRecorder: AudioRecorder
    private let meetingStore: MeetingStore
    private let settingsStore: AppSettingsStore
    private var speechClient: SpeechClient?
    private var subtitleDisplay = SubtitleDisplayBuffer()
    private var lastStoredTranscriptKey: String?

    var speechMode: SpeechMode {
        settingsStore.settings.speechMode
    }

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
        subtitleDisplay.reset()
        lastStoredTranscriptKey = nil
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
                onStatus(
                    "正在录音：\(audioDeviceManager.selectedDeviceName())",
                    "\(configuration.title)：音频保存到 \(meeting.audioURL.lastPathComponent)"
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

private struct SubtitleDisplayBuffer {
    private var committedSources: [String] = []
    private var committedTranslations: [String] = []
    private var currentSource = ""
    private var currentTranslation = ""
    private var lastCommittedSource = ""
    private var lastCommittedTranslation = ""

    mutating func reset() {
        committedSources.removeAll(keepingCapacity: true)
        committedTranslations.removeAll(keepingCapacity: true)
        currentSource = ""
        currentTranslation = ""
        lastCommittedSource = ""
        lastCommittedTranslation = ""
    }

    mutating func apply(_ event: RealtimeSpeechEvent) -> (source: String, translation: String) {
        let source = event.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let translation = event.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch event.kind {
        case .sourceStart:
            currentSource = ""
        case .sourceInterim:
            if source.isEmpty == false {
                currentSource = source
            }
        case .sourceFinal:
            if source.isEmpty == false {
                currentSource = source
            }
            commitCurrentSource()
        case .translationStart:
            currentTranslation = ""
        case .translationInterim:
            if translation.isEmpty == false {
                currentTranslation = translation
            }
        case .translationFinal:
            if translation.isEmpty == false {
                currentTranslation = translation
            }
            commitCurrentTranslation()
        case .system:
            break
        }

        return (
            visibleLines(committedSources, currentSource).joined(separator: "\n"),
            visibleLines(committedTranslations, currentTranslation).joined(separator: "\n")
        )
    }

    private mutating func commitCurrentSource() {
        let text = currentSource.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return }
        if text != lastCommittedSource {
            committedSources.append(text)
            lastCommittedSource = text
        }
        currentSource = ""
    }

    private mutating func commitCurrentTranslation() {
        let text = currentTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return }
        if text != lastCommittedTranslation {
            committedTranslations.append(text)
            lastCommittedTranslation = text
        }
        currentTranslation = ""
    }

    private func visibleLines(_ committed: [String], _ current: String) -> [String] {
        let draft = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if draft.isEmpty {
            return committed
        }
        return committed + [draft]
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

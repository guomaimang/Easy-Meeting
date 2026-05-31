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

            guard event.sourceLanguage != "system" else {
                onStatus(event.sourceText, event.translatedText)
                return
            }

            let display = subtitleDisplay.apply(event)
            onStatus(display.source, display.translation)

            guard event.isFinal, event.translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
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
            onStatus("录音已保存", meeting?.directoryURL.path ?? "会议目录已更新")
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
    private struct Line: Equatable {
        var source: String
        var translation: String

        var isEmpty: Bool {
            source.isEmpty && translation.isEmpty
        }
    }

    private var committed: [Line] = []
    private var current: Line?
    private var lastCommitted: Line?

    mutating func reset() {
        committed.removeAll(keepingCapacity: true)
        current = nil
        lastCommitted = nil
    }

    mutating func apply(_ event: RealtimeSpeechEvent) -> (source: String, translation: String) {
        let source = event.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let translation = event.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)

        if source.isEmpty == false || translation.isEmpty == false {
            let previousSource = current?.source ?? ""
            let previousTranslation = current?.translation ?? ""
            current = Line(
                source: source.isEmpty ? previousSource : source,
                translation: translation.isEmpty ? previousTranslation : translation
            )
        }

        if event.isFinal, let line = current, line.isEmpty == false, line.translation.isEmpty == false {
            if line != lastCommitted {
                committed.append(line)
                lastCommitted = line
            }
            current = nil
        }

        let visible = committed + [current].compactMap { $0 }
        return (
            visible.map(\.source).joined(separator: "\n"),
            visible.map(\.translation).joined(separator: "\n")
        )
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

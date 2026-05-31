import Foundation

@MainActor
protocol SpeechClient: AnyObject, Sendable {
    var isRunning: Bool { get }

    func start(
        configuration: SpeechTranslationConfiguration,
        meetingID: UUID,
        onEvent: @escaping @MainActor (RealtimeSpeechEvent) -> Void
    )

    func sendAudioFrame(_ frame: AudioFrame)

    func stop()
}

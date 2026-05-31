import Foundation

@MainActor
protocol SpeechClient {
    var isRunning: Bool { get }

    func start(
        mode: SpeechMode,
        meetingID: UUID,
        onEvent: @escaping @MainActor (RealtimeSpeechEvent) -> Void
    )

    func stop()
}

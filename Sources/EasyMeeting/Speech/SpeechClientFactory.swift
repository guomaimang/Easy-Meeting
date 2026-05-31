import Foundation

@MainActor
enum SpeechClientFactory {
    static func make(settings: AppSettings) -> SpeechClient {
        switch settings.speechProvider {
        case .mock:
            MockSpeechClient()
        case .volcengine:
            VolcengineASTSpeechClient(settings: settings)
        }
    }
}

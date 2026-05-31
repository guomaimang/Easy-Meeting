import Foundation

@MainActor
enum SpeechClientFactory {
    static func make(settings: AppSettings) -> SpeechClient {
        switch settings.speechProvider {
        case .volcengine:
            VolcengineHelperSpeechClient(settings: settings)
        case .azure:
            AzureHelperSpeechClient(settings: settings)
        }
    }
}

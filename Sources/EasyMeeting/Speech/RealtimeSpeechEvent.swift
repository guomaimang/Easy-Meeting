import Foundation

struct RealtimeSpeechEvent {
    let sourceText: String
    let translatedText: String
    let startMilliseconds: Int
    let endMilliseconds: Int
    let sourceLanguage: String
    let targetLanguage: String
    let isFinal: Bool
}

import Foundation

struct RealtimeSpeechEvent {
    enum Kind {
        case sourceStart
        case sourceInterim
        case sourceFinal
        case translationStart
        case translationInterim
        case translationFinal
        case system
    }

    let kind: Kind
    let sourceText: String
    let translatedText: String
    let startMilliseconds: Int
    let endMilliseconds: Int
    let sourceLanguage: String
    let targetLanguage: String
    let isInterim: Bool
    let isFinal: Bool
}

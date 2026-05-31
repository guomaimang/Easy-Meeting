import Foundation

struct StoredTranscriptSegment {
    let startMilliseconds: Int
    let endMilliseconds: Int?
    let sourceText: String
    let translatedText: String?
    let sourceLanguage: String?
    let targetLanguage: String?
    let isFinal: Bool
}

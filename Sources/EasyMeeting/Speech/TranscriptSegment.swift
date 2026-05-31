import Foundation

struct TranscriptSegment: Identifiable {
    let id: UUID
    let meetingID: UUID
    let startMilliseconds: Int
    let endMilliseconds: Int?
    let sourceText: String
    let translatedText: String?
    let sourceLanguage: String
    let targetLanguage: String
    let isFinal: Bool
    let vendorPayload: String?
    let createdAt: Date
}

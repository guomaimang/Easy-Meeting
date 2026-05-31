import Foundation

struct StoredMeetingSummary: Encodable, Identifiable {
    let id: UUID
    let title: String
    let startedAt: String
    let endedAt: String?
    let directoryPath: String
    let audioPath: String
}

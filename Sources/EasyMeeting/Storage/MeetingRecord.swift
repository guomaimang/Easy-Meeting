import Foundation

struct MeetingRecord: Identifiable {
    let id: UUID
    let title: String
    let startedAt: Date
    var endedAt: Date?
    let directoryURL: URL
    let audioURL: URL
}

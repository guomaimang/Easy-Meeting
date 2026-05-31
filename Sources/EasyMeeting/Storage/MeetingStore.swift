import Foundation

@MainActor
final class MeetingStore {
    private let database: SQLiteDatabase?
    private(set) var currentMeeting: MeetingRecord?
    private(set) var initializationError: Error?

    init() {
        do {
            database = try SQLiteDatabase(url: AppStorage.databaseURL())
        } catch {
            database = nil
            initializationError = error
        }
    }

    func startMeeting(title: String = "未命名会议", mode: SpeechMode) throws -> MeetingRecord {
        if let initializationError {
            throw initializationError
        }

        let id = UUID()
        let startedAt = Date()
        let directoryURL = try Self.createMeetingDirectory(id: id, startedAt: startedAt)
        let audioURL = directoryURL.appendingPathComponent("audio.m4a")

        let meeting = MeetingRecord(
            id: id,
            title: title,
            startedAt: startedAt,
            endedAt: nil,
            directoryURL: directoryURL,
            audioURL: audioURL
        )

        try writeMetadata(for: meeting)
        try database?.upsertMeeting(meeting)
        currentMeeting = meeting
        return meeting
    }

    func finishCurrentMeeting() throws -> MeetingRecord? {
        guard var meeting = currentMeeting else { return nil }

        meeting.endedAt = Date()
        try writeMetadata(for: meeting)
        try database?.upsertMeeting(meeting)
        currentMeeting = nil
        return meeting
    }

    func addTranscriptSegment(from event: RealtimeSpeechEvent) throws {
        guard let meeting = currentMeeting else { return }

        let segment = TranscriptSegment(
            id: UUID(),
            meetingID: meeting.id,
            startMilliseconds: event.startMilliseconds,
            endMilliseconds: event.endMilliseconds,
            sourceText: event.sourceText,
            translatedText: event.translatedText,
            sourceLanguage: event.sourceLanguage,
            targetLanguage: event.targetLanguage,
            isFinal: event.isFinal,
            vendorPayload: nil,
            createdAt: Date()
        )

        try database?.insertTranscriptSegment(segment)
        try appendTranscriptLine(segment, meeting: meeting)
    }

    func recentMeetings() throws -> [StoredMeetingSummary] {
        if let initializationError {
            throw initializationError
        }

        return try database?.fetchRecentMeetings() ?? []
    }

    func exportMeeting(_ meeting: StoredMeetingSummary) throws -> [URL] {
        if let initializationError {
            throw initializationError
        }

        let segments = try database?.fetchTranscriptSegments(meetingID: meeting.id) ?? []
        return try MeetingExporter.export(meeting: meeting, segments: segments)
    }

    private func writeMetadata(for meeting: MeetingRecord) throws {
        let metadata = MeetingMetadata(
            id: meeting.id.uuidString,
            title: meeting.title,
            startedAt: meeting.startedAt,
            endedAt: meeting.endedAt,
            audioFileName: meeting.audioURL.lastPathComponent
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(metadata)
        let metadataURL = meeting.directoryURL.appendingPathComponent("metadata.json")
        try data.write(to: metadataURL, options: .atomic)
    }

    private func appendTranscriptLine(_ segment: TranscriptSegment, meeting: MeetingRecord) throws {
        let sourceLine = "[\(segment.startMilliseconds)ms] \(segment.sourceText)"
        let translatedLine = segment.translatedText.map { "    \($0)" }
        let combinedText = ([sourceLine, translatedLine].compactMap { $0 } + [""]).joined(separator: "\n")

        try append(combinedText, to: meeting.directoryURL.appendingPathComponent("transcript.txt"))
        try append(sourceLine + "\n", to: meeting.directoryURL.appendingPathComponent("transcript-source.txt"))

        if let translatedLine {
            let translationURL = meeting.directoryURL.appendingPathComponent("transcript-translation.txt")
            let translationText = translatedLine.trimmingCharacters(in: .whitespaces) + "\n"
            try append(translationText, to: translationURL)
        }
    }

    private func append(_ text: String, to url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) == false {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return
        }

        let handle = try FileHandle(forWritingTo: url)
        defer {
            try? handle.close()
        }

        try handle.seekToEnd()
        if let data = text.data(using: .utf8) {
            try handle.write(contentsOf: data)
        }
    }

    private static func createMeetingDirectory(id: UUID, startedAt: Date) throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"

        let folderName = "\(formatter.string(from: startedAt))_\(id.uuidString)"
        let directoryURL = try AppStorage.meetingsURL().appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }
}

private struct MeetingMetadata: Encodable {
    let id: String
    let title: String
    let startedAt: Date
    let endedAt: Date?
    let audioFileName: String
}

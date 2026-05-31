import Foundation

enum MeetingExporter {
    static func export(meeting: StoredMeetingSummary, segments: [StoredTranscriptSegment]) throws -> [URL] {
        let directoryURL = URL(fileURLWithPath: meeting.directoryPath, isDirectory: true)
        let markdownURL = directoryURL.appendingPathComponent("transcript.md")
        let srtURL = directoryURL.appendingPathComponent("transcript.srt")
        let jsonURL = directoryURL.appendingPathComponent("transcript.json")

        try markdown(meeting: meeting, segments: segments).write(to: markdownURL, atomically: true, encoding: .utf8)
        try srt(segments: segments).write(to: srtURL, atomically: true, encoding: .utf8)
        try json(meeting: meeting, segments: segments).write(to: jsonURL, options: .atomic)

        return [URL(fileURLWithPath: meeting.audioPath), markdownURL, srtURL, jsonURL]
    }

    private static func markdown(meeting: StoredMeetingSummary, segments: [StoredTranscriptSegment]) -> String {
        var lines = [
            "# \(meeting.title)",
            "",
            "- 开始时间：\(meeting.startedAt)",
            "- 结束时间：\(meeting.endedAt ?? "进行中")",
            ""
        ]

        for segment in segments {
            lines.append("## \(timecode(milliseconds: segment.startMilliseconds))")
            lines.append(segment.sourceText)
            if let translatedText = segment.translatedText, translatedText.isEmpty == false {
                lines.append("")
                lines.append(translatedText)
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private static func srt(segments: [StoredTranscriptSegment]) -> String {
        segments.enumerated().map { index, segment in
            let end = segment.endMilliseconds ?? segment.startMilliseconds + 1_800
            let text = [segment.sourceText, segment.translatedText].compactMap { $0 }.joined(separator: "\n")

            return """
            \(index + 1)
            \(srtTime(milliseconds: segment.startMilliseconds)) --> \(srtTime(milliseconds: end))
            \(text)

            """
        }.joined(separator: "\n")
    }

    private static func json(meeting: StoredMeetingSummary, segments: [StoredTranscriptSegment]) throws -> Data {
        let payload = ExportPayload(
            meeting: meeting,
            segments: segments.map(ExportSegment.init)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    private static func timecode(milliseconds: Int) -> String {
        let seconds = milliseconds / 1_000
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private static func srtTime(milliseconds: Int) -> String {
        let hours = milliseconds / 3_600_000
        let minutes = milliseconds % 3_600_000 / 60_000
        let seconds = milliseconds % 60_000 / 1_000
        let millis = milliseconds % 1_000
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, millis)
    }
}

private struct ExportPayload: Encodable {
    let meeting: StoredMeetingSummary
    let segments: [ExportSegment]
}

private struct ExportSegment: Encodable {
    let startMilliseconds: Int
    let endMilliseconds: Int?
    let sourceText: String
    let translatedText: String?
    let sourceLanguage: String?
    let targetLanguage: String?
    let isFinal: Bool

    init(_ segment: StoredTranscriptSegment) {
        startMilliseconds = segment.startMilliseconds
        endMilliseconds = segment.endMilliseconds
        sourceText = segment.sourceText
        translatedText = segment.translatedText
        sourceLanguage = segment.sourceLanguage
        targetLanguage = segment.targetLanguage
        isFinal = segment.isFinal
    }
}

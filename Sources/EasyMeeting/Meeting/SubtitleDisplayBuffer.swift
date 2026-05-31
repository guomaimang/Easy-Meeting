import Foundation

struct SubtitleDisplayBuffer {
    private var meetingStartedAt = Date()
    private var committedSources: [TimedSubtitleLine] = []
    private var committedTranslations: [TimedSubtitleLine] = []
    private var currentSource: TimedSubtitleLine?
    private var currentTranslation: TimedSubtitleLine?
    private var lastCommittedSource = ""
    private var lastCommittedTranslation = ""

    mutating func reset() {
        meetingStartedAt = Date()
        committedSources.removeAll(keepingCapacity: true)
        committedTranslations.removeAll(keepingCapacity: true)
        currentSource = nil
        currentTranslation = nil
        lastCommittedSource = ""
        lastCommittedTranslation = ""
    }

    mutating func apply(_ event: RealtimeSpeechEvent) -> (source: String, translation: String) {
        let source = event.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let translation = event.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let timestampMilliseconds = timestampMilliseconds(for: event)

        switch event.kind {
        case .sourceStart:
            currentSource = nil
        case .sourceInterim:
            if source.isEmpty == false {
                currentSource = TimedSubtitleLine(milliseconds: timestampMilliseconds, text: source)
            }
        case .sourceFinal:
            if source.isEmpty == false {
                currentSource = TimedSubtitleLine(milliseconds: timestampMilliseconds, text: source)
            }
            commitCurrentSource()
        case .translationStart:
            currentTranslation = nil
        case .translationInterim:
            if translation.isEmpty == false {
                currentTranslation = TimedSubtitleLine(milliseconds: timestampMilliseconds, text: translation)
            }
        case .translationFinal:
            if translation.isEmpty == false {
                currentTranslation = TimedSubtitleLine(milliseconds: timestampMilliseconds, text: translation)
            }
            commitCurrentTranslation()
        case .system:
            break
        }

        return (
            visibleLines(committedSources, currentSource).joined(separator: "\n"),
            visibleLines(committedTranslations, currentTranslation).joined(separator: "\n")
        )
    }

    private mutating func commitCurrentSource() {
        guard let line = currentSource else { return }
        if line.text != lastCommittedSource {
            committedSources.append(line)
            lastCommittedSource = line.text
        }
        currentSource = nil
    }

    private mutating func commitCurrentTranslation() {
        guard let line = currentTranslation else { return }
        if line.text != lastCommittedTranslation {
            committedTranslations.append(line)
            lastCommittedTranslation = line.text
        }
        currentTranslation = nil
    }

    private func visibleLines(_ committed: [TimedSubtitleLine], _ current: TimedSubtitleLine?) -> [String] {
        let lines = current.map { committed + [$0] } ?? committed
        return lines.map(\.displayText)
    }

    private func timestampMilliseconds(for event: RealtimeSpeechEvent) -> Int {
        if event.startMilliseconds > 0 {
            return event.startMilliseconds
        }
        return max(Int(Date().timeIntervalSince(meetingStartedAt) * 1000), 0)
    }
}

private struct TimedSubtitleLine {
    let milliseconds: Int
    let text: String

    var displayText: String {
        "\(Self.timecode(milliseconds: milliseconds)): \(text)"
    }

    private static func timecode(milliseconds: Int) -> String {
        let totalSeconds = max(milliseconds, 0) / 1000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

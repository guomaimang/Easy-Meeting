import Foundation

enum VolcengineHelperError: LocalizedError {
    case notRunning

    var errorDescription: String? {
        "火山 helper 未运行。"
    }
}

enum VolcengineHelperCommand: Encodable {
    case start(
        apiKey: String,
        resourceID: String,
        mode: String,
        sourceLanguage: String,
        targetLanguage: String,
        meetingID: String
    )
    case audio(
        sampleRate: Int,
        channels: Int,
        bitsPerChannel: Int,
        timestampMilliseconds: Int,
        dataBase64: String
    )
    case finish

    private enum CodingKeys: String, CodingKey {
        case type
        case apiKey
        case resourceID
        case mode
        case sourceLanguage
        case targetLanguage
        case meetingID
        case sampleRate
        case channels
        case bitsPerChannel
        case timestampMilliseconds
        case dataBase64
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .start(apiKey, resourceID, mode, sourceLanguage, targetLanguage, meetingID):
            try container.encode("start", forKey: .type)
            try container.encode(apiKey, forKey: .apiKey)
            try container.encode(resourceID, forKey: .resourceID)
            try container.encode(mode, forKey: .mode)
            try container.encode(sourceLanguage, forKey: .sourceLanguage)
            try container.encode(targetLanguage, forKey: .targetLanguage)
            try container.encode(meetingID, forKey: .meetingID)
        case let .audio(sampleRate, channels, bitsPerChannel, timestampMilliseconds, dataBase64):
            try container.encode("audio", forKey: .type)
            try container.encode(sampleRate, forKey: .sampleRate)
            try container.encode(channels, forKey: .channels)
            try container.encode(bitsPerChannel, forKey: .bitsPerChannel)
            try container.encode(timestampMilliseconds, forKey: .timestampMilliseconds)
            try container.encode(dataBase64, forKey: .dataBase64)
        case .finish:
            try container.encode("finish", forKey: .type)
        }
    }
}

struct VolcengineHelperEvent: Decodable {
    let type: String
    let message: String?
    let detail: String?
    let text: String?
    let sourceText: String?
    let translatedText: String?
    let startMilliseconds: Int?
    let endMilliseconds: Int?
    let sourceLanguage: String?
    let targetLanguage: String?
    let isInterim: Bool?
    let isFinal: Bool?
}

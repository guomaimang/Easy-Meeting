import Foundation

enum AzureHelperError: LocalizedError {
    case notRunning

    var errorDescription: String? {
        "Azure helper 未运行。"
    }
}

enum AzureHelperCommand: Encodable {
    case start(
        speechKey: String,
        region: String,
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
        case speechKey
        case region
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
        case let .start(speechKey, region, sourceLanguage, targetLanguage, meetingID):
            try container.encode("start", forKey: .type)
            try container.encode(speechKey, forKey: .speechKey)
            try container.encode(region, forKey: .region)
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

struct AzureHelperEvent: Decodable {
    let type: String
    let message: String?
    let detail: String?
    let sourceText: String?
    let translatedText: String?
    let isInterim: Bool?
    let isFinal: Bool?
}

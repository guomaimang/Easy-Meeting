import Foundation
import SwiftProtobuf

struct VolcengineASTProtocol {
    let appKey: String
    let resourceID: String
    let connectionID: String
    let sessionID: String

    func startSession(mode: SpeechMode, sequence: Int32) throws -> Data {
        var request = baseRequest(event: .startSession, sequence: sequence)
        request.user = user()
        request.sourceAudio = audioDescription(
            data: Data(),
            sampleRate: AudioStreamFormat.sampleRate,
            channels: AudioStreamFormat.channels,
            bitsPerChannel: AudioStreamFormat.bitsPerChannel
        )
        request.targetAudio = targetAudioDescription()
        request.request = requestParams(mode: mode)
        request.denoise = true
        return try request.serializedData()
    }

    func audioFrame(_ frame: AudioFrame, sequence: Int32) throws -> Data {
        var request = baseRequest(event: .taskRequest, sequence: sequence)
        request.sourceAudio = audioDescription(
            data: frame.data,
            sampleRate: frame.sampleRate,
            channels: frame.channels,
            bitsPerChannel: normalizedBitsPerChannel(frame.bitsPerChannel)
        )
        return try request.serializedData()
    }

    func finishSession(sequence: Int32) throws -> Data {
        try baseRequest(event: .finishSession, sequence: sequence).serializedData()
    }

    func decodeResponse(_ data: Data) throws -> VolcengineASTResponse {
        let response = try Data_Speech_Ast_TranslateResponse(serializedBytes: data)
        return VolcengineASTResponse(response: response)
    }

    private func baseRequest(event: Data_Speech_Event_Type, sequence: Int32) -> Data_Speech_Ast_TranslateRequest {
        var request = Data_Speech_Ast_TranslateRequest()
        request.event = event
        request.requestMeta = requestMeta(sequence: sequence)
        return request
    }

    private func requestMeta(sequence: Int32) -> Data_Speech_Common_RequestMeta {
        var meta = Data_Speech_Common_RequestMeta()
        meta.endpoint = "ast"
        meta.appKey = appKey
        meta.resourceID = resourceID
        meta.connectionID = connectionID
        meta.sessionID = sessionID
        meta.sequence = sequence
        return meta
    }

    private func user() -> Data_Speech_Understanding_User {
        var user = Data_Speech_Understanding_User()
        user.uid = "easy-meeting"
        user.platform = "macos"
        user.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "debug"
        return user
    }

    private func requestParams(mode: SpeechMode) -> Data_Speech_Ast_ReqParams {
        var params = Data_Speech_Ast_ReqParams()
        params.mode = "s2t"
        params.sourceLanguage = mode.sourceLanguage
        params.targetLanguage = mode.targetLanguage
        return params
    }

    private func targetAudioDescription() -> Data_Speech_Understanding_Audio {
        var audio = Data_Speech_Understanding_Audio()
        audio.format = "pcm"
        audio.codec = "raw"
        audio.rate = Int32(AudioStreamFormat.sampleRate)
        audio.bits = Int32(AudioStreamFormat.bitsPerChannel)
        audio.channel = Int32(AudioStreamFormat.channels)
        return audio
    }

    private func audioDescription(
        data: Data,
        sampleRate: Int,
        channels: Int,
        bitsPerChannel: Int
    ) -> Data_Speech_Understanding_Audio {
        var audio = Data_Speech_Understanding_Audio()
        audio.format = "pcm"
        audio.codec = "raw"
        audio.rate = Int32(sampleRate)
        audio.bits = Int32(bitsPerChannel)
        audio.channel = Int32(max(channels, 1))
        audio.binaryData = data
        return audio
    }

    private func normalizedBitsPerChannel(_ value: Int) -> Int {
        value > 0 ? value : 16
    }
}

struct VolcengineASTResponse {
    let event: Data_Speech_Event_Type
    let text: String
    let startMilliseconds: Int
    let endMilliseconds: Int
    let statusCode: Int32
    let message: String

    init(response: Data_Speech_Ast_TranslateResponse) {
        event = response.event
        text = response.text
        startMilliseconds = Int(response.startTime)
        endMilliseconds = Int(response.endTime)
        statusCode = response.responseMeta.statusCode
        message = response.responseMeta.message
    }

    var isFailure: Bool {
        event == .connectionFailed || event == .sessionFailed || statusCode >= 400
    }

    var isSubtitle: Bool {
        switch event {
        case .sourceSubtitleResponse, .sourceSubtitleEnd, .translationSubtitleResponse, .translationSubtitleEnd:
            true
        default:
            false
        }
    }

    var isTranslation: Bool {
        event == .translationSubtitleResponse || event == .translationSubtitleEnd
    }

    var isFinal: Bool {
        event == .sourceSubtitleEnd || event == .translationSubtitleEnd
    }
}

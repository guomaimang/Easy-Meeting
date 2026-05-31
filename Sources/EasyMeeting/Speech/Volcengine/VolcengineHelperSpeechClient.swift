import Foundation

@MainActor
final class VolcengineHelperSpeechClient: SpeechClient, @unchecked Sendable {
    private let settings: AppSettings
    private var process: Process?
    private var input: FileHandle?
    private var outputBuffer = Data()
    private var onEvent: (@MainActor (RealtimeSpeechEvent) -> Void)?
    private(set) var isRunning = false

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start(
        mode: SpeechMode,
        meetingID: UUID,
        onEvent: @escaping @MainActor (RealtimeSpeechEvent) -> Void
    ) {
        self.onEvent = onEvent

        guard settings.volcengineAppKey.isEmpty == false else {
            emitStatus("火山引擎未配置", "请先在设置里填写 App Key。")
            return
        }

        guard settings.volcengineAccessKey.isEmpty == false else {
            emitStatus("火山引擎未配置", "请先在设置里填写 Access Key。")
            return
        }

        guard let helperURL = helperURL() else {
            emitStatus("火山 helper 缺失", "未找到 easy-meeting-ast-helper。")
            return
        }

        do {
            try launchHelper(at: helperURL)
            try send(HelperCommand.start(
                appKey: settings.volcengineAppKey,
                accessKey: settings.volcengineAccessKey,
                resourceID: settings.volcengineResourceID,
                mode: mode.rawValue,
                sourceLanguage: mode.sourceLanguage,
                targetLanguage: mode.targetLanguage,
                meetingID: meetingID.uuidString
            ))
            isRunning = true
        } catch {
            emitStatus("火山 helper 启动失败", error.localizedDescription)
            stop()
        }
    }

    func sendAudioFrame(_ frame: AudioFrame) {
        guard isRunning else { return }

        do {
            try send(HelperCommand.audio(
                sampleRate: frame.sampleRate,
                channels: frame.channels,
                bitsPerChannel: frame.bitsPerChannel,
                timestampMilliseconds: frame.timestampMilliseconds,
                dataBase64: frame.data.base64EncodedString()
            ))
        } catch {
            emitStatus("火山音频发送失败", error.localizedDescription)
        }
    }

    func stop() {
        if isRunning {
            try? send(HelperCommand.finish)
        }
        input?.closeFile()
        process?.terminate()
        process = nil
        input = nil
        isRunning = false
        onEvent = nil
        outputBuffer.removeAll(keepingCapacity: false)
    }

    private func launchHelper(at url: URL) throws {
        let process = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = url
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                self?.handleTermination(status: process.terminationStatus)
            }
        }

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard data.isEmpty == false else { return }
            Task { @MainActor in
                self?.handleOutput(data)
            }
        }

        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard data.isEmpty == false else { return }
            Task { @MainActor in
                self?.handleStderr(data)
            }
        }

        try process.run()
        self.process = process
        input = stdin.fileHandleForWriting
    }

    private func helperURL() -> URL? {
        let bundleHelper = Bundle.main.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Helpers")
            .appendingPathComponent("easy-meeting-ast-helper")
        if FileManager.default.isExecutableFile(atPath: bundleHelper.path) {
            return bundleHelper
        }

        let debugHelper = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build")
            .appendingPathComponent("debug")
            .appendingPathComponent("easy-meeting-ast-helper")
        if FileManager.default.isExecutableFile(atPath: debugHelper.path) {
            return debugHelper
        }

        return nil
    }

    private func send(_ command: HelperCommand) throws {
        guard let input else { throw HelperError.notRunning }
        let data = try JSONEncoder().encode(command)
        input.write(data)
        input.write(Data([0x0A]))
    }

    private func handleOutput(_ data: Data) {
        outputBuffer.append(data)

        while let newline = outputBuffer.firstIndex(of: 0x0A) {
            let line = outputBuffer[..<newline]
            outputBuffer.removeSubrange(...newline)
            guard line.isEmpty == false else { continue }
            handleLine(Data(line))
        }
    }

    private func handleLine(_ data: Data) {
        do {
            let event = try JSONDecoder().decode(HelperEvent.self, from: data)
            switch event.type {
            case "status":
                emitStatus(event.message ?? "火山 helper 状态", event.detail ?? "")
            case "subtitle":
                emitSpeechEvent(event)
            case "error":
                emitStatus("火山 helper 错误", event.message ?? "未知错误")
            default:
                emitStatus("火山 helper 未知事件", event.type)
            }
        } catch {
            emitStatus("火山 helper 输出解析失败", error.localizedDescription)
        }
    }

    private func emitSpeechEvent(_ event: HelperEvent) {
        onEvent?(RealtimeSpeechEvent(
            sourceText: event.sourceText ?? "",
            translatedText: event.translatedText ?? "",
            startMilliseconds: event.startMilliseconds ?? 0,
            endMilliseconds: event.endMilliseconds ?? 0,
            sourceLanguage: event.sourceLanguage ?? "auto",
            targetLanguage: event.targetLanguage ?? "zh",
            isFinal: event.isFinal ?? false
        ))
    }

    private func handleStderr(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        emitStatus("火山 helper 日志", text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func handleTermination(status: Int32) {
        guard isRunning else { return }
        emitStatus("火山 helper 已退出", "退出码：\(status)")
        isRunning = false
    }

    private func emitStatus(_ source: String, _ translation: String) {
        onEvent?(RealtimeSpeechEvent(
            sourceText: source,
            translatedText: translation,
            startMilliseconds: 0,
            endMilliseconds: 0,
            sourceLanguage: "system",
            targetLanguage: "zh",
            isFinal: true
        ))
    }
}

private enum HelperError: LocalizedError {
    case notRunning

    var errorDescription: String? {
        "火山 helper 未运行。"
    }
}

private enum HelperCommand: Encodable {
    case start(
        appKey: String,
        accessKey: String,
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
        case appKey
        case accessKey
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
        case let .start(appKey, accessKey, resourceID, mode, sourceLanguage, targetLanguage, meetingID):
            try container.encode("start", forKey: .type)
            try container.encode(appKey, forKey: .appKey)
            try container.encode(accessKey, forKey: .accessKey)
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

private struct HelperEvent: Decodable {
    let type: String
    let message: String?
    let detail: String?
    let sourceText: String?
    let translatedText: String?
    let startMilliseconds: Int?
    let endMilliseconds: Int?
    let sourceLanguage: String?
    let targetLanguage: String?
    let isFinal: Bool?
}

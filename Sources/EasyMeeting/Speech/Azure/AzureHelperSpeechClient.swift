import Foundation

@MainActor
final class AzureHelperSpeechClient: SpeechClient, @unchecked Sendable {
    private let settings: AppSettings
    private var process: Process?
    private var input: FileHandle?
    private var outputBuffer = Data()
    private var onEvent: (@MainActor (RealtimeSpeechEvent) -> Void)?
    private var sourceLanguageCode = "en-US"
    private var targetLanguageCode = "zh-Hans"
    private(set) var isRunning = false

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start(
        configuration: SpeechTranslationConfiguration,
        meetingID: UUID,
        onEvent: @escaping @MainActor (RealtimeSpeechEvent) -> Void
    ) {
        self.onEvent = onEvent

        guard settings.azureSpeechKey.isEmpty == false else {
            emitStatus("Azure 未配置", "请先在设置里填写语音密钥。")
            return
        }
        guard settings.azureSpeechRegion.isEmpty == false else {
            emitStatus("Azure 未配置", "请先在设置里填写区域。")
            return
        }

        let validation = AzureLanguageMapping.validate(configuration)
        guard validation.isValid,
              let sourceCode = AzureLanguageMapping.recognitionCode(for: configuration.sourceLanguage),
              let targetCode = AzureLanguageMapping.translationCode(for: configuration.targetLanguage) else {
            emitStatus("Azure 语种不支持", validation.message ?? "请更换源语种或目标语种。")
            return
        }
        sourceLanguageCode = sourceCode
        targetLanguageCode = targetCode

        guard let nodeURL = AzureHelperRuntime.nodeURL() else {
            emitStatus("Azure helper 缺失", "未找到 node，请先安装 Node.js。")
            return
        }
        guard let scriptURL = AzureHelperRuntime.scriptURL() else {
            emitStatus("Azure helper 缺失", "未找到 AzureSpeechHelper/index.js。")
            return
        }

        do {
            try launchHelper(node: nodeURL, script: scriptURL)
            try send(AzureHelperCommand.start(
                speechKey: settings.azureSpeechKey,
                region: settings.azureSpeechRegion,
                sourceLanguage: sourceCode,
                targetLanguage: targetCode,
                meetingID: meetingID.uuidString
            ))
            isRunning = true
        } catch {
            emitStatus("Azure helper 启动失败", error.localizedDescription)
            stop()
        }
    }

    func sendAudioFrame(_ frame: AudioFrame) {
        guard isRunning else { return }

        do {
            try send(AzureHelperCommand.audio(
                sampleRate: frame.sampleRate,
                channels: frame.channels,
                bitsPerChannel: frame.bitsPerChannel,
                timestampMilliseconds: frame.timestampMilliseconds,
                dataBase64: frame.data.base64EncodedString()
            ))
        } catch {
            emitStatus("Azure 音频发送失败", error.localizedDescription)
        }
    }

    func stop() {
        if isRunning {
            try? send(AzureHelperCommand.finish)
        }
        input?.closeFile()
        process?.terminate()
        process = nil
        input = nil
        isRunning = false
        onEvent = nil
        outputBuffer.removeAll(keepingCapacity: false)
    }

    private func launchHelper(node: URL, script: URL) throws {
        let process = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = node
        process.arguments = [script.path]
        process.currentDirectoryURL = script.deletingLastPathComponent()
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

    private func send(_ command: AzureHelperCommand) throws {
        guard let input else { throw AzureHelperError.notRunning }
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
            let event = try JSONDecoder().decode(AzureHelperEvent.self, from: data)
            switch event.type {
            case "status":
                NSLog("Azure helper 状态：%@ %@", event.message ?? "", event.detail ?? "")
            case "source", "source_end", "translation", "translation_end":
                emitSpeechEvent(event)
            case "error":
                emitStatus("Azure helper 错误", event.message ?? "未知错误")
            default:
                emitStatus("Azure helper 未知事件", event.type)
            }
        } catch {
            emitStatus("Azure helper 输出解析失败", error.localizedDescription)
        }
    }

    private func emitSpeechEvent(_ event: AzureHelperEvent) {
        let kind = speechEventKind(for: event.type)
        onEvent?(RealtimeSpeechEvent(
            kind: kind,
            sourceText: event.sourceText ?? "",
            translatedText: event.translatedText ?? "",
            startMilliseconds: 0,
            endMilliseconds: 0,
            sourceLanguage: sourceLanguageCode,
            targetLanguage: targetLanguageCode,
            isInterim: event.isInterim ?? false,
            isFinal: event.isFinal ?? false
        ))
    }

    private func speechEventKind(for type: String) -> RealtimeSpeechEvent.Kind {
        switch type {
        case "source":
            return .sourceInterim
        case "source_end":
            return .sourceFinal
        case "translation":
            return .translationInterim
        case "translation_end":
            return .translationFinal
        default:
            return .system
        }
    }

    private func handleStderr(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        NSLog("Azure helper 日志：%@", text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func handleTermination(status: Int32) {
        guard isRunning else { return }
        emitStatus("Azure helper 已退出", "退出码：\(status)")
        isRunning = false
    }

    private func emitStatus(_ source: String, _ translation: String) {
        onEvent?(RealtimeSpeechEvent(
            kind: .system,
            sourceText: source,
            translatedText: translation,
            startMilliseconds: 0,
            endMilliseconds: 0,
            sourceLanguage: "system",
            targetLanguage: "zh",
            isInterim: false,
            isFinal: true
        ))
    }
}

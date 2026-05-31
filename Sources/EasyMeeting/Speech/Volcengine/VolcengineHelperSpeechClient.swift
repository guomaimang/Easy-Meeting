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

        guard settings.volcengineAPIKey.isEmpty == false else {
            emitStatus("火山引擎未配置", "请先在设置里填写 API Key。")
            return
        }

        guard let helperURL = VolcengineHelperRuntime.helperURL() else {
            emitStatus("火山 helper 缺失", "未找到 easy-meeting-ast-helper。")
            return
        }

        do {
            try launchHelper(at: helperURL)
            try send(VolcengineHelperCommand.start(
                apiKey: settings.volcengineAPIKey,
                resourceID: AppSettings.volcengineResourceID,
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
            try send(VolcengineHelperCommand.audio(
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
            try? send(VolcengineHelperCommand.finish)
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

    private func send(_ command: VolcengineHelperCommand) throws {
        guard let input else { throw VolcengineHelperError.notRunning }
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
            let event = try JSONDecoder().decode(VolcengineHelperEvent.self, from: data)
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

    private func emitSpeechEvent(_ event: VolcengineHelperEvent) {
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

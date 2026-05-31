import Foundation

@MainActor
final class VolcengineASTSpeechClient: NSObject, SpeechClient, @unchecked Sendable {
    private let settings: AppSettings
    private var webSocketTask: URLSessionWebSocketTask?
    private(set) var isRunning = false
    private var onEvent: (@MainActor (RealtimeSpeechEvent) -> Void)?
    private var astProtocol: VolcengineASTProtocol?
    private var sequence: Int32 = 0
    private var latestSourceText = ""

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

        guard let url = URL(string: "wss://openspeech.bytedance.com/api/v4/ast/v2/translate") else {
            emitStatus("火山引擎地址无效", "无法创建 WebSocket URL。")
            return
        }

        var request = URLRequest(url: url)
        request.setValue(settings.volcengineAppKey, forHTTPHeaderField: "X-Api-App-Key")
        request.setValue(settings.volcengineAccessKey, forHTTPHeaderField: "X-Api-Access-Key")
        request.setValue(settings.volcengineResourceID, forHTTPHeaderField: "X-Api-Resource-Id")
        let connectionID = UUID().uuidString
        let sessionID = meetingID.uuidString
        request.setValue(connectionID, forHTTPHeaderField: "X-Api-Connect-Id")

        let task = URLSession.shared.webSocketTask(with: request)
        webSocketTask = task
        astProtocol = VolcengineASTProtocol(
            appKey: settings.volcengineAppKey,
            resourceID: settings.volcengineResourceID,
            connectionID: connectionID,
            sessionID: sessionID
        )
        sequence = 0
        latestSourceText = ""
        isRunning = true
        task.resume()
        receive()
        sendStartSession(mode: mode)
    }

    func sendAudioFrame(_ frame: AudioFrame) {
        guard isRunning, let astProtocol else { return }

        do {
            let data = try astProtocol.audioFrame(frame, sequence: nextSequence())
            send(data)
        } catch {
            emitStatus("火山音频编码失败", error.localizedDescription)
        }
    }

    func stop() {
        sendFinishSession()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isRunning = false
        onEvent = nil
        astProtocol = nil
    }

    private func receive() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }

                switch result {
                case let .success(message):
                    self.handle(message)
                    if self.isRunning {
                        self.receive()
                    }
                case let .failure(error):
                    self.emitStatus("火山引擎连接断开", error.localizedDescription)
                    self.stop()
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case let .string(text):
            emitStatus("火山引擎返回文本", text)
        case let .data(data):
            handleProtobufResponse(data)
        @unknown default:
            emitStatus("火山引擎返回未知消息", "暂未支持的 WebSocket 消息类型。")
        }
    }

    private func sendStartSession(mode: SpeechMode) {
        guard let astProtocol else { return }

        do {
            let data = try astProtocol.startSession(mode: mode, sequence: nextSequence())
            send(data)
            emitStatus("火山引擎连接已启动", "已发送 AST StartSession。")
        } catch {
            emitStatus("火山会话启动失败", error.localizedDescription)
        }
    }

    private func sendFinishSession() {
        guard isRunning, let astProtocol else { return }

        do {
            let data = try astProtocol.finishSession(sequence: nextSequence())
            send(data)
        } catch {
            emitStatus("火山会话结束失败", error.localizedDescription)
        }
    }

    private func send(_ data: Data) {
        webSocketTask?.send(.data(data)) { [weak self] error in
            guard let error else { return }

            Task { @MainActor in
                self?.emitStatus("火山消息发送失败", error.localizedDescription)
            }
        }
    }

    private func handleProtobufResponse(_ data: Data) {
        guard let astProtocol else { return }

        do {
            let response = try astProtocol.decodeResponse(data)
            if response.isFailure {
                emitStatus("火山语音服务错误", response.message)
            } else if response.isSubtitle {
                emitSubtitle(response)
            }
        } catch {
            emitStatus("火山响应解析失败", error.localizedDescription)
        }
    }

    private func emitSubtitle(_ response: VolcengineASTResponse) {
        if response.isTranslation {
            emitEvent(
                source: latestSourceText,
                translation: response.text,
                response: response
            )
        } else {
            latestSourceText = response.text
            emitEvent(
                source: response.text,
                translation: "",
                response: response
            )
        }
    }

    private func emitEvent(source: String, translation: String, response: VolcengineASTResponse) {
        onEvent?(RealtimeSpeechEvent(
            sourceText: source,
            translatedText: translation,
            startMilliseconds: response.startMilliseconds,
            endMilliseconds: response.endMilliseconds,
            sourceLanguage: "auto",
            targetLanguage: "zh",
            isFinal: response.isFinal
        ))
    }

    private func nextSequence() -> Int32 {
        sequence += 1
        return sequence
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

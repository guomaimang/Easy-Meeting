import Foundation

@MainActor
final class VolcengineASTSpeechClient: NSObject, SpeechClient {
    private let settings: AppSettings
    private var webSocketTask: URLSessionWebSocketTask?
    private(set) var isRunning = false
    private var onEvent: (@MainActor (RealtimeSpeechEvent) -> Void)?

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
            emitStatus("火山引擎未配置", "请先在设置里填写 API Key。")
            return
        }

        guard let url = URL(string: "wss://openspeech.bytedance.com/api/v4/ast/v2/translate") else {
            emitStatus("火山引擎地址无效", "无法创建 WebSocket URL。")
            return
        }

        var request = URLRequest(url: url)
        request.setValue(settings.volcengineAppKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue(settings.volcengineResourceID, forHTTPHeaderField: "X-Api-Resource-Id")

        let task = URLSession.shared.webSocketTask(with: request)
        webSocketTask = task
        isRunning = true
        task.resume()
        receive()
        emitStatus("火山引擎连接已启动", "等待 AST protobuf 音频协议接入。")
    }

    func stop() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isRunning = false
        onEvent = nil
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
        case .data:
            emitStatus("火山引擎返回二进制数据", "AST 返回为 protobuf，等待 codec 解析。")
        @unknown default:
            emitStatus("火山引擎返回未知消息", "暂未支持的 WebSocket 消息类型。")
        }
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

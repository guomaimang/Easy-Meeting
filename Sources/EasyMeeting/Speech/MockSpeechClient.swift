import Foundation

@MainActor
final class MockSpeechClient: SpeechClient {
    private var task: Task<Void, Never>?
    private(set) var isRunning = false

    func start(
        mode: SpeechMode,
        meetingID: UUID,
        onEvent: @escaping @MainActor (RealtimeSpeechEvent) -> Void
    ) {
        stop()
        isRunning = true

        let samples = Self.samples(for: mode)
        task = Task { @MainActor in
            for (index, sample) in samples.enumerated() {
                guard Task.isCancelled == false else { return }

                try? await Task.sleep(for: .seconds(index == 0 ? 1 : 2))
                guard Task.isCancelled == false else { return }

                onEvent(RealtimeSpeechEvent(
                    sourceText: sample.source,
                    translatedText: sample.translation,
                    startMilliseconds: index * 2_000,
                    endMilliseconds: index * 2_000 + 1_800,
                    sourceLanguage: mode.sourceLanguage,
                    targetLanguage: mode.targetLanguage,
                    isFinal: true
                ))
            }

            isRunning = false
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isRunning = false
    }

    private static func samples(for mode: SpeechMode) -> [(source: String, translation: String)] {
        switch mode {
        case .englishToChinese:
            [
                ("Let's quickly review the project timeline.", "我们快速回顾一下项目时间线。"),
                ("The first milestone is the local recording flow.", "第一个里程碑是本地录音流程。"),
                ("After that, we will connect the realtime speech API.", "之后我们会接入实时语音 API。")
            ]
        case .cantoneseToChinese:
            [
                ("我哋而家睇下今日会议重点。", "我们现在看一下今天的会议重点。"),
                ("呢个版本先做好录音同字幕。", "这个版本先做好录音和字幕。"),
                ("之后再测试粤语识别质量。", "之后再测试粤语识别质量。")
            ]
        case .chineseEnglishBidirectional:
            [
                ("这个功能需要低延迟。", "This feature needs low latency."),
                ("We should keep the storage local first.", "我们应该先保持本地存储。"),
                ("后面再加云端同步。", "We can add cloud sync later.")
            ]
        }
    }
}

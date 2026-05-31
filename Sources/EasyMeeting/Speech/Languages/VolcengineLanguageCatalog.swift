import Foundation

/// 火山引擎 AST 同声传译的语言表（源/目标共用一套代号）。
///
/// 语言约束：
/// - 非中英互译：源或目标其中之一必须为中文或英文。
/// - 中英互译 `zhen`：源和目标必须同时为 `zhen`。
/// 数据来源：豆包语音同声传译 2.0 API 文档与 docs/volcengine-ast-api.md。
enum VolcengineLanguageCatalog {
    /// 源语种（含方言与 zhen）。
    static let sourceLanguages: [SpeechLanguageOption] = [
        SpeechLanguageOption(code: "zh", label: "中文"),
        SpeechLanguageOption(code: "en", label: "英文"),
        SpeechLanguageOption(code: "ja", label: "日语"),
        SpeechLanguageOption(code: "ko", label: "韩语"),
        SpeechLanguageOption(code: "de", label: "德语"),
        SpeechLanguageOption(code: "fr", label: "法语"),
        SpeechLanguageOption(code: "es", label: "西班牙语"),
        SpeechLanguageOption(code: "pt", label: "葡萄牙语"),
        SpeechLanguageOption(code: "id", label: "印尼语"),
        SpeechLanguageOption(code: "it", label: "意大利语"),
        SpeechLanguageOption(code: "ru", label: "俄语"),
        SpeechLanguageOption(code: "tr", label: "土耳其语"),
        SpeechLanguageOption(code: "ms", label: "马来语"),
        SpeechLanguageOption(code: "nl", label: "荷兰语"),
        SpeechLanguageOption(code: "ro", label: "罗马尼亚语"),
        SpeechLanguageOption(code: "pl", label: "波兰语"),
        SpeechLanguageOption(code: "cs", label: "捷克语"),
        SpeechLanguageOption(code: "ar", label: "阿拉伯语"),
        SpeechLanguageOption(code: "th", label: "泰语"),
        SpeechLanguageOption(code: "vi", label: "越南语"),
        SpeechLanguageOption(code: "yue-CN", label: "粤语"),
        SpeechLanguageOption(code: "sh-CN", label: "上海话"),
        SpeechLanguageOption(code: "zhen", label: "中英反转互译")
    ]

    /// 目标语种：方言（粤语、上海话）不能作为翻译目标。
    static let targetLanguages: [SpeechLanguageOption] = sourceLanguages.filter { option in
        option.code != "yue-CN" && option.code != "sh-CN"
    }
}

import Foundation

/// Azure 语音翻译的语言表（会议常用精选）。
///
/// 识别语言（源）用 BCP-47 带地区后缀，翻译语言（目标）用简码/脚本码，
/// 两套代号不同，同一种语言在源和目标里写法也不同（如中文：zh-CN / zh-Hans）。
/// 数据来源：https://learn.microsoft.com/azure/ai-services/speech-service/language-support
enum AzureLanguageCatalog {
    /// 识别语言（源）。
    static let recognitionLanguages: [SpeechLanguageOption] = [
        SpeechLanguageOption(code: "zh-CN", label: "中文（普通话）"),
        SpeechLanguageOption(code: "zh-HK", label: "中文（粤语，繁体）"),
        SpeechLanguageOption(code: "yue-CN", label: "粤语（简体）"),
        SpeechLanguageOption(code: "en-US", label: "英语（美国）"),
        SpeechLanguageOption(code: "en-GB", label: "英语（英国）"),
        SpeechLanguageOption(code: "ja-JP", label: "日语"),
        SpeechLanguageOption(code: "ko-KR", label: "韩语"),
        SpeechLanguageOption(code: "fr-FR", label: "法语"),
        SpeechLanguageOption(code: "de-DE", label: "德语"),
        SpeechLanguageOption(code: "es-ES", label: "西班牙语"),
        SpeechLanguageOption(code: "pt-BR", label: "葡萄牙语（巴西）"),
        SpeechLanguageOption(code: "ru-RU", label: "俄语"),
        SpeechLanguageOption(code: "it-IT", label: "意大利语"),
        SpeechLanguageOption(code: "th-TH", label: "泰语"),
        SpeechLanguageOption(code: "vi-VN", label: "越南语"),
        SpeechLanguageOption(code: "id-ID", label: "印尼语"),
        SpeechLanguageOption(code: "ar-SA", label: "阿拉伯语"),
        SpeechLanguageOption(code: "hi-IN", label: "印地语")
    ]

    /// 翻译语言（目标）。
    static let translationLanguages: [SpeechLanguageOption] = [
        SpeechLanguageOption(code: "zh-Hans", label: "中文（简体）"),
        SpeechLanguageOption(code: "zh-Hant", label: "中文（繁体）"),
        SpeechLanguageOption(code: "yue", label: "粤语"),
        SpeechLanguageOption(code: "en", label: "英语"),
        SpeechLanguageOption(code: "ja", label: "日语"),
        SpeechLanguageOption(code: "ko", label: "韩语"),
        SpeechLanguageOption(code: "fr", label: "法语"),
        SpeechLanguageOption(code: "de", label: "德语"),
        SpeechLanguageOption(code: "es", label: "西班牙语"),
        SpeechLanguageOption(code: "pt", label: "葡萄牙语"),
        SpeechLanguageOption(code: "ru", label: "俄语"),
        SpeechLanguageOption(code: "it", label: "意大利语"),
        SpeechLanguageOption(code: "th", label: "泰语"),
        SpeechLanguageOption(code: "vi", label: "越南语"),
        SpeechLanguageOption(code: "id", label: "印尼语"),
        SpeechLanguageOption(code: "ar", label: "阿拉伯语"),
        SpeechLanguageOption(code: "hi", label: "印地语")
    ]
}

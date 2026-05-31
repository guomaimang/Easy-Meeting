import Foundation

/// 把项目内部的 `SpeechLanguage`（火山码）映射到 Azure 语音翻译所需的语种码。
///
/// - 识别语言（源）：BCP-47，如 `en-US`、`zh-CN`、`yue-CN`。
/// - 翻译语言（目标）：简码或脚本码，如 `zh-Hans`、`en`、`ja`。
///
/// 数据来源：https://learn.microsoft.com/azure/ai-services/speech-service/language-support
enum AzureLanguageMapping {
    /// 源语种 → Azure 识别码。
    static func recognitionCode(for language: SpeechLanguage) -> String? {
        switch language {
        case .zh: "zh-CN"
        case .en: "en-US"
        case .de: "de-DE"
        case .fr: "fr-FR"
        case .es: "es-ES"
        case .id: "id-ID"
        case .ja: "ja-JP"
        case .pt: "pt-BR"
        case .ko: "ko-KR"
        case .tr: "tr-TR"
        case .ms: "ms-MY"
        case .nl: "nl-NL"
        case .ro: "ro-RO"
        case .pl: "pl-PL"
        case .cs: "cs-CZ"
        case .ar: "ar-SA"
        case .th: "th-TH"
        case .vi: "vi-VN"
        case .ru: "ru-RU"
        case .it: "it-IT"
        case .yueCN: "yue-CN"
        case .shCN: "wuu-CN"
        case .zhen: nil
        }
    }

    /// 目标语种 → Azure 翻译码。
    static func translationCode(for language: SpeechLanguage) -> String? {
        switch language {
        case .zh: "zh-Hans"
        case .en: "en"
        case .de: "de"
        case .fr: "fr"
        case .es: "es"
        case .id: "id"
        case .ja: "ja"
        case .pt: "pt"
        case .ko: "ko"
        case .tr: "tr"
        case .ms: "ms"
        case .nl: "nl"
        case .ro: "ro"
        case .pl: "pl"
        case .cs: "cs"
        case .ar: "ar"
        case .th: "th"
        case .vi: "vi"
        case .ru: "ru"
        case .it: "it"
        case .yueCN, .shCN, .zhen: nil
        }
    }

    /// 校验源/目标语种是否能映射到 Azure 翻译。
    static func validate(_ configuration: SpeechTranslationConfiguration) -> AzureLanguageValidation {
        if configuration.sourceLanguage == .zhen || configuration.targetLanguage == .zhen {
            return .invalid("Azure 不支持中英反转互译（zhen），请改用火山引擎或选择具体源/目标语种。")
        }
        guard recognitionCode(for: configuration.sourceLanguage) != nil else {
            return .invalid("Azure 不支持该源语种：\(configuration.sourceLanguage.title)。")
        }
        guard translationCode(for: configuration.targetLanguage) != nil else {
            return .invalid("Azure 不支持该目标语种：\(configuration.targetLanguage.title)。")
        }
        return .valid
    }
}

enum AzureLanguageValidation {
    case valid
    case invalid(String)

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    var message: String? {
        if case let .invalid(message) = self { return message }
        return nil
    }
}

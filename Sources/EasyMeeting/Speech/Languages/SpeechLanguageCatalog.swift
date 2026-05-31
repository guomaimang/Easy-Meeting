import Foundation

/// 按服务商提供语言列表、默认值与语种对校验。
/// 对应 ref 的 getLanguagesByProvider / getTranslationLanguages / validate*。
enum SpeechLanguageCatalog {
    /// 源语种列表。
    static func sourceLanguages(for provider: SpeechProvider) -> [SpeechLanguageOption] {
        switch provider {
        case .volcengine: VolcengineLanguageCatalog.sourceLanguages
        case .azure: AzureLanguageCatalog.recognitionLanguages
        }
    }

    /// 目标语种列表。
    static func targetLanguages(for provider: SpeechProvider) -> [SpeechLanguageOption] {
        switch provider {
        case .volcengine: VolcengineLanguageCatalog.targetLanguages
        case .azure: AzureLanguageCatalog.translationLanguages
        }
    }

    static func defaultSourceCode(for provider: SpeechProvider) -> String {
        switch provider {
        case .volcengine: "en"
        case .azure: "en-US"
        }
    }

    static func defaultTargetCode(for provider: SpeechProvider) -> String {
        switch provider {
        case .volcengine: "zh"
        case .azure: "zh-Hans"
        }
    }

    /// 校验代号是否属于该服务商，无效则回落到默认值。
    static func validatedSourceCode(_ code: String, for provider: SpeechProvider) -> String {
        let codes = sourceLanguages(for: provider).map(\.code)
        return codes.contains(code) ? code : defaultSourceCode(for: provider)
    }

    static func validatedTargetCode(_ code: String, for provider: SpeechProvider) -> String {
        let codes = targetLanguages(for: provider).map(\.code)
        return codes.contains(code) ? code : defaultTargetCode(for: provider)
    }

    static func sourceLabel(_ code: String, for provider: SpeechProvider) -> String {
        sourceLanguages(for: provider).first { $0.code == code }?.label ?? code
    }

    static func targetLabel(_ code: String, for provider: SpeechProvider) -> String {
        targetLanguages(for: provider).first { $0.code == code }?.label ?? code
    }

    /// 校验源/目标语种对是否合法。
    static func validatePair(
        provider: SpeechProvider,
        sourceCode: String,
        targetCode: String
    ) -> SpeechLanguageValidation {
        switch provider {
        case .volcengine:
            validateVolcenginePair(sourceCode: sourceCode, targetCode: targetCode)
        case .azure:
            validateAzurePair(sourceCode: sourceCode, targetCode: targetCode)
        }
    }

    private static func validateVolcenginePair(sourceCode: String, targetCode: String) -> SpeechLanguageValidation {
        if sourceCode == "zhen" || targetCode == "zhen" {
            guard sourceCode == "zhen" && targetCode == "zhen" else {
                return .invalid("中英反转互译模式下，源语种和目标语种都必须选择「中英反转互译」。")
            }
            return .valid
        }
        if sourceCode == targetCode {
            return .invalid("源语种和目标语种不能相同。")
        }
        let chineseOrEnglish: Set<String> = ["zh", "en"]
        guard chineseOrEnglish.contains(sourceCode) || chineseOrEnglish.contains(targetCode) else {
            return .invalid("火山非互译模式下，源语种或目标语种必须包含中文或英文。")
        }
        return .valid
    }

    private static func validateAzurePair(sourceCode: String, targetCode: String) -> SpeechLanguageValidation {
        guard AzureLanguageCatalog.recognitionLanguages.contains(where: { $0.code == sourceCode }) else {
            return .invalid("Azure 不支持该源语种：\(sourceCode)。")
        }
        guard AzureLanguageCatalog.translationLanguages.contains(where: { $0.code == targetCode }) else {
            return .invalid("Azure 不支持该目标语种：\(targetCode)。")
        }
        return .valid
    }
}

enum SpeechLanguageValidation {
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

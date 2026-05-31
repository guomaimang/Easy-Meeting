import Foundation

/// 一次翻译会话的语种配置：服务商 + 源/目标代号。
///
/// 代号是当前服务商的原生代号（Azure 源 `en-US`、目标 `zh-Hans`；火山 `en`/`zh`/`zhen`），
/// 不做跨服务商统一，由各自的 SpeechClient 直接透传给 helper。
struct SpeechTranslationConfiguration {
    let provider: SpeechProvider
    let sourceCode: String
    let targetCode: String

    var sourceLabel: String {
        SpeechLanguageCatalog.sourceLabel(sourceCode, for: provider)
    }

    var targetLabel: String {
        SpeechLanguageCatalog.targetLabel(targetCode, for: provider)
    }

    var title: String {
        "\(sourceLabel)转\(targetLabel)"
    }

    var detail: String {
        "\(sourceCode) → \(targetCode)"
    }

    var validation: SpeechLanguageValidation {
        SpeechLanguageCatalog.validatePair(provider: provider, sourceCode: sourceCode, targetCode: targetCode)
    }
}

import Foundation

struct AppSettings {
    static let volcengineResourceID = "volc.service_type.10053"

    var speechProvider: SpeechProvider
    var speechMode: SpeechMode
    var speechSourceLanguage: String
    var speechTargetLanguage: String
    var volcengineAPIKey: String
    var azureSpeechKey: String
    var azureSpeechRegion: String
    var overlayOpacity: Double
    var overlayFontSize: Double
    /// 悬浮窗右侧"备注"栏开关，关闭时回到两栏布局。
    var overlayNotesEnabled: Bool
    /// 备注栏要显示的演示稿 / 提词文本，多行长文本。
    var overlayNotesText: String

    static let defaults = AppSettings(
        speechProvider: .volcengine,
        speechMode: .englishToChinese,
        speechSourceLanguage: "en",
        speechTargetLanguage: "zh",
        volcengineAPIKey: "",
        azureSpeechKey: "",
        azureSpeechRegion: "eastasia",
        overlayOpacity: 0.82,
        overlayFontSize: 22,
        overlayNotesEnabled: false,
        overlayNotesText: ""
    )

    var effectiveAzureSpeechRegion: String {
        let region = azureSpeechRegion.trimmingCharacters(in: .whitespacesAndNewlines)
        return region.isEmpty ? Self.defaults.azureSpeechRegion : region
    }

    var speechConfiguration: SpeechTranslationConfiguration {
        SpeechTranslationConfiguration(
            provider: speechProvider,
            sourceCode: speechSourceLanguage,
            targetCode: speechTargetLanguage
        )
    }
}

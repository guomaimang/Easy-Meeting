import Foundation

@MainActor
final class AppSettingsStore {
    private enum Keys {
        static let speechProvider = "speechProvider"
        static let speechMode = "speechMode"
        static let speechSourceLanguage = "speechSourceLanguage"
        static let speechTargetLanguage = "speechTargetLanguage"
        static let volcengineAPIKey = "volcengineAPIKey"
        static let overlayOpacity = "overlayOpacity"
        static let overlayFontSize = "overlayFontSize"
    }

    private let defaults = UserDefaults.standard
    private(set) var settings: AppSettings

    init() {
        let fallback = AppSettings.defaults
        let providerRawValue = defaults.string(forKey: Keys.speechProvider) ?? fallback.speechProvider.rawValue
        let provider = SpeechProvider(rawValue: providerRawValue) ?? fallback.speechProvider
        let modeRawValue = defaults.string(forKey: Keys.speechMode) ?? fallback.speechMode.rawValue
        let speechMode = SpeechMode(rawValue: modeRawValue) ?? fallback.speechMode
        let sourceRawValue = defaults.string(forKey: Keys.speechSourceLanguage) ?? speechMode.sourceLanguage
        let targetRawValue = defaults.string(forKey: Keys.speechTargetLanguage) ?? speechMode.targetLanguage
        let sourceLanguage = SpeechLanguage(rawValue: sourceRawValue) ?? fallback.speechSourceLanguage
        let targetLanguage = SpeechLanguage(rawValue: targetRawValue) ?? fallback.speechTargetLanguage
        let apiKey = KeychainStore.read(account: Keys.volcengineAPIKey)
        let overlayOpacity = defaults.object(forKey: Keys.overlayOpacity) as? Double ?? fallback.overlayOpacity
        let overlayFontSize = defaults.object(forKey: Keys.overlayFontSize) as? Double ?? fallback.overlayFontSize

        settings = AppSettings(
            speechProvider: provider,
            speechMode: speechMode,
            speechSourceLanguage: sourceLanguage,
            speechTargetLanguage: targetLanguage,
            volcengineAPIKey: apiKey,
            overlayOpacity: Self.clampedOpacity(overlayOpacity),
            overlayFontSize: Self.clampedFontSize(overlayFontSize)
        )
    }

    func save(_ settings: AppSettings) throws {
        defaults.set(settings.speechProvider.rawValue, forKey: Keys.speechProvider)
        defaults.set(settings.speechMode.rawValue, forKey: Keys.speechMode)
        defaults.set(settings.speechSourceLanguage.rawValue, forKey: Keys.speechSourceLanguage)
        defaults.set(settings.speechTargetLanguage.rawValue, forKey: Keys.speechTargetLanguage)
        defaults.set(Self.clampedOpacity(settings.overlayOpacity), forKey: Keys.overlayOpacity)
        defaults.set(Self.clampedFontSize(settings.overlayFontSize), forKey: Keys.overlayFontSize)
        try KeychainStore.write(settings.volcengineAPIKey, account: Keys.volcengineAPIKey)
        self.settings = AppSettings(
            speechProvider: settings.speechProvider,
            speechMode: settings.speechMode,
            speechSourceLanguage: settings.speechSourceLanguage,
            speechTargetLanguage: settings.speechTargetLanguage,
            volcengineAPIKey: settings.volcengineAPIKey,
            overlayOpacity: Self.clampedOpacity(settings.overlayOpacity),
            overlayFontSize: Self.clampedFontSize(settings.overlayFontSize)
        )
    }

    func saveOverlayOpacity(_ opacity: Double) throws {
        var updatedSettings = settings
        updatedSettings.overlayOpacity = Self.clampedOpacity(opacity)
        try save(updatedSettings)
    }

    private static func clampedOpacity(_ opacity: Double) -> Double {
        min(max(opacity, 0.25), 1)
    }

    private static func clampedFontSize(_ fontSize: Double) -> Double {
        min(max(fontSize, 14), 34)
    }
}

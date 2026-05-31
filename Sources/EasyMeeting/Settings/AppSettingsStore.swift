import Foundation

@MainActor
final class AppSettingsStore {
    private enum Keys {
        static let speechProvider = "speechProvider"
        static let volcengineAPIKey = "volcengineAPIKey"
        static let overlayOpacity = "overlayOpacity"
    }

    private let defaults = UserDefaults.standard
    private(set) var settings: AppSettings

    init() {
        let fallback = AppSettings.defaults
        let providerRawValue = defaults.string(forKey: Keys.speechProvider) ?? fallback.speechProvider.rawValue
        let provider = SpeechProvider(rawValue: providerRawValue) ?? fallback.speechProvider
        let apiKey = KeychainStore.read(account: Keys.volcengineAPIKey)
        let overlayOpacity = defaults.object(forKey: Keys.overlayOpacity) as? Double ?? fallback.overlayOpacity

        settings = AppSettings(
            speechProvider: provider,
            volcengineAPIKey: apiKey,
            overlayOpacity: Self.clampedOpacity(overlayOpacity)
        )
    }

    func save(_ settings: AppSettings) throws {
        defaults.set(settings.speechProvider.rawValue, forKey: Keys.speechProvider)
        defaults.set(Self.clampedOpacity(settings.overlayOpacity), forKey: Keys.overlayOpacity)
        try KeychainStore.write(settings.volcengineAPIKey, account: Keys.volcengineAPIKey)
        self.settings = AppSettings(
            speechProvider: settings.speechProvider,
            volcengineAPIKey: settings.volcengineAPIKey,
            overlayOpacity: Self.clampedOpacity(settings.overlayOpacity)
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
}

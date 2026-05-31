import Foundation

@MainActor
final class AppSettingsStore {
    private enum Keys {
        static let speechProvider = "speechProvider"
        static let volcengineResourceID = "volcengineResourceID"
        static let volcengineAppKey = "volcengineAppKey"
    }

    private let defaults = UserDefaults.standard
    private(set) var settings: AppSettings

    init() {
        let fallback = AppSettings.defaults
        let providerRawValue = defaults.string(forKey: Keys.speechProvider) ?? fallback.speechProvider.rawValue
        let provider = SpeechProvider(rawValue: providerRawValue) ?? fallback.speechProvider
        let resourceID = defaults.string(forKey: Keys.volcengineResourceID) ?? fallback.volcengineResourceID
        let appKey = KeychainStore.read(account: Keys.volcengineAppKey)

        settings = AppSettings(
            speechProvider: provider,
            volcengineResourceID: resourceID,
            volcengineAppKey: appKey
        )
    }

    func save(_ settings: AppSettings) throws {
        defaults.set(settings.speechProvider.rawValue, forKey: Keys.speechProvider)
        defaults.set(settings.volcengineResourceID, forKey: Keys.volcengineResourceID)
        try KeychainStore.write(settings.volcengineAppKey, account: Keys.volcengineAppKey)
        self.settings = settings
    }
}

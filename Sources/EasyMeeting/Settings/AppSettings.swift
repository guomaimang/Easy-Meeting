import Foundation

struct AppSettings {
    var speechProvider: SpeechProvider
    var volcengineResourceID: String
    var volcengineAppKey: String

    static let defaults = AppSettings(
        speechProvider: .mock,
        volcengineResourceID: "volc.service_type.10053",
        volcengineAppKey: ""
    )
}

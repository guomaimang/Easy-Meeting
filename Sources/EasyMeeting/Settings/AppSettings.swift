import Foundation

struct AppSettings {
    var speechProvider: SpeechProvider
    var volcengineResourceID: String
    var volcengineAppKey: String
    var volcengineAccessKey: String

    static let defaults = AppSettings(
        speechProvider: .volcengine,
        volcengineResourceID: "volc.service_type.10053",
        volcengineAppKey: "",
        volcengineAccessKey: ""
    )
}

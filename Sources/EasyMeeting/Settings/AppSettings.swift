import Foundation

struct AppSettings {
    static let volcengineResourceID = "volc.service_type.10053"

    var speechProvider: SpeechProvider
    var volcengineAPIKey: String
    var overlayOpacity: Double

    static let defaults = AppSettings(
        speechProvider: .volcengine,
        volcengineAPIKey: "",
        overlayOpacity: 0.82
    )
}

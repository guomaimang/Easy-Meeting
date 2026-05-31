import Foundation

struct AppSettings {
    static let volcengineResourceID = "volc.service_type.10053"

    var speechProvider: SpeechProvider
    var speechMode: SpeechMode
    var volcengineAPIKey: String
    var overlayOpacity: Double
    var overlayFontSize: Double

    static let defaults = AppSettings(
        speechProvider: .volcengine,
        speechMode: .englishToChinese,
        volcengineAPIKey: "",
        overlayOpacity: 0.82,
        overlayFontSize: 22
    )
}

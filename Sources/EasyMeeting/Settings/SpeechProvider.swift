import Foundation

enum SpeechProvider: String, CaseIterable {
    case volcengine
    case azure

    var title: String {
        switch self {
        case .volcengine:
            "火山引擎"
        case .azure:
            "Azure"
        }
    }
}

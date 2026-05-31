import Foundation

enum SpeechProvider: String, CaseIterable {
    case volcengine

    var title: String {
        switch self {
        case .volcengine:
            "火山引擎"
        }
    }
}

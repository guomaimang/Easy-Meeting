import Foundation

enum SpeechProvider: String, CaseIterable {
    case mock
    case volcengine

    var title: String {
        switch self {
        case .mock:
            "模拟服务"
        case .volcengine:
            "火山引擎"
        }
    }
}

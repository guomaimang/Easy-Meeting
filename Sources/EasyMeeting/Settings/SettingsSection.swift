import Foundation

enum SettingsSection: Int, CaseIterable {
    case app
    case speech
    case microphone

    var title: String {
        switch self {
        case .app: "程序"
        case .speech: "语音"
        case .microphone: "麦克风"
        }
    }
}

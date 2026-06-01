import Foundation

enum SettingsSection: Int, CaseIterable {
    case app
    case speech
    case microphone
    case notes

    var title: String {
        switch self {
        case .app: "程序"
        case .speech: "语音"
        case .microphone: "麦克风"
        case .notes: "备注"
        }
    }

    var groupTitle: String {
        switch self {
        case .app, .speech:
            "通用"
        case .microphone:
            "输入"
        case .notes:
            "演示"
        }
    }

    var iconName: String {
        switch self {
        case .app:
            "slider.horizontal.3"
        case .speech:
            "waveform.and.mic"
        case .microphone:
            "mic"
        case .notes:
            "note.text"
        }
    }
}

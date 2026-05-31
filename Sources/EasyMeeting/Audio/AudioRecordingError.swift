import Foundation

enum AudioRecordingError: LocalizedError {
    case permissionDenied
    case deviceNotFound
    case cannotCreateInput
    case cannotAddInput
    case cannotAddOutput
    case cannotCreateWriter
    case writerFailed(String)
    case notRecording

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "麦克风权限未允许"
        case .deviceNotFound:
            "没有找到选择的麦克风"
        case .cannotCreateInput:
            "无法创建麦克风输入"
        case .cannotAddInput:
            "无法添加麦克风输入"
        case .cannotAddOutput:
            "无法添加音频输出"
        case .cannotCreateWriter:
            "无法创建录音文件"
        case let .writerFailed(message):
            "录音写入失败：\(message)"
        case .notRecording:
            "当前没有正在录制的会议"
        }
    }
}

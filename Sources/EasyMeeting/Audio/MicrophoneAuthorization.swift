import AVFoundation

enum MicrophoneAuthorization: Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unknown

    var title: String {
        switch self {
        case .notDetermined:
            "麦克风权限：未请求"
        case .authorized:
            "麦克风权限：已允许"
        case .denied:
            "麦克风权限：已拒绝"
        case .restricted:
            "麦克风权限：受限制"
        case .unknown:
            "麦克风权限：未知"
        }
    }

    static func current() -> MicrophoneAuthorization {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            .notDetermined
        case .authorized:
            .authorized
        case .denied:
            .denied
        case .restricted:
            .restricted
        @unknown default:
            .unknown
        }
    }
}

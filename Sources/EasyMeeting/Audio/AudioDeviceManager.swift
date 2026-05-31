import AVFoundation

@MainActor
final class AudioDeviceManager {
    private(set) var authorization: MicrophoneAuthorization = .current()
    private(set) var devices: [AudioInputDevice] = []
    private(set) var selectedDeviceID: String?

    init() {
        refreshDevices()
    }

    func requestPermission() async -> MicrophoneAuthorization {
        if authorization == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            authorization = granted ? .authorized : .denied
        } else {
            authorization = .current()
        }

        refreshDevices()
        return authorization
    }

    func refreshDevices() {
        authorization = .current()

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )

        let defaultDeviceID = AVCaptureDevice.default(for: .audio)?.uniqueID
        devices = discoverySession.devices.map { device in
            AudioInputDevice(
                id: device.uniqueID,
                name: device.localizedName,
                isDefault: device.uniqueID == defaultDeviceID
            )
        }

        if selectedDeviceID == nil {
            selectedDeviceID = defaultDeviceID ?? devices.first?.id
        }

        if let selectedDeviceID, devices.contains(where: { $0.id == selectedDeviceID }) == false {
            self.selectedDeviceID = defaultDeviceID ?? devices.first?.id
        }
    }

    func selectDevice(id: String) {
        guard devices.contains(where: { $0.id == id }) else { return }
        selectedDeviceID = id
    }

    func selectedDeviceName() -> String {
        guard let selectedDeviceID,
              let device = devices.first(where: { $0.id == selectedDeviceID }) else {
            return "未选择麦克风"
        }

        return device.name
    }
}

@preconcurrency import AVFoundation

final class AudioRecorder: NSObject {
    private let captureQueue = DispatchQueue(label: "easy-meeting.audio.capture")
    private var session: AVCaptureSession?
    private var output: AVCaptureAudioDataOutput?
    private var writer: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var didStartWriting = false
    private(set) var isRecording = false

    func startRecording(to url: URL, selectedDeviceID: String?) throws {
        stopCaptureOnly()

        let device = try selectedCaptureDevice(id: selectedDeviceID)
        let input = try AVCaptureDeviceInput(device: device)
        let output = AVCaptureAudioDataOutput()
        let session = AVCaptureSession()

        guard session.canAddInput(input) else {
            throw AudioRecordingError.cannotAddInput
        }
        session.addInput(input)

        guard session.canAddOutput(output) else {
            throw AudioRecordingError.cannotAddOutput
        }
        session.addOutput(output)

        let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 96_000
        ]
        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        writerInput.expectsMediaDataInRealTime = true

        guard writer.canAdd(writerInput) else {
            throw AudioRecordingError.cannotCreateWriter
        }
        writer.add(writerInput)

        output.setSampleBufferDelegate(self, queue: captureQueue)

        self.session = session
        self.output = output
        self.writer = writer
        self.writerInput = writerInput
        didStartWriting = false
        isRecording = true

        captureQueue.async {
            session.startRunning()
        }
    }

    func stopRecording(completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        guard isRecording else {
            completion(.failure(AudioRecordingError.notRecording))
            return
        }

        isRecording = false
        let writerBox = writer.map(AssetWriterBox.init)
        let writerInput = writerInput
        stopCaptureOnly()

        writerInput?.markAsFinished()
        writerBox?.writer.finishWriting {
            if let error = writerBox?.writer.error {
                completion(.failure(AudioRecordingError.writerFailed(error.localizedDescription)))
            } else {
                completion(.success(()))
            }
        }
    }

    private func stopCaptureOnly() {
        output?.setSampleBufferDelegate(nil, queue: nil)
        session?.stopRunning()
        session = nil
        output = nil
        writer = nil
        writerInput = nil
        didStartWriting = false
    }

    private func selectedCaptureDevice(id selectedDeviceID: String?) throws -> AVCaptureDevice {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )

        if let selectedDeviceID,
           let device = discoverySession.devices.first(where: { $0.uniqueID == selectedDeviceID }) {
            return device
        }

        if let defaultDevice = AVCaptureDevice.default(for: .audio) {
            return defaultDevice
        }

        throw AudioRecordingError.deviceNotFound
    }
}

private final class AssetWriterBox: @unchecked Sendable {
    let writer: AVAssetWriter

    init(writer: AVAssetWriter) {
        self.writer = writer
    }
}

extension AudioRecorder: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        append(sampleBuffer)
    }

    private func append(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording,
              let writer,
              let writerInput else {
            return
        }

        if didStartWriting == false {
            writer.startWriting()
            writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            didStartWriting = true
        }

        if writer.status == .failed {
            isRecording = false
            return
        }

        if writerInput.isReadyForMoreMediaData {
            writerInput.append(sampleBuffer)
        }
    }
}

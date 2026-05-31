 @preconcurrency import AVFoundation

final class AudioRecorder: NSObject {
    private let captureQueue = DispatchQueue(label: "easy-meeting.audio.capture")
    private var session: AVCaptureSession?
    private var output: AVCaptureAudioDataOutput?
    private var writer: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var didStartWriting = false
    private(set) var isRecording = false
    var onAudioFrame: (@Sendable (AudioFrame) -> Void)?

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

        output.audioSettings = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: AudioStreamFormat.sampleRate,
            AVNumberOfChannelsKey: AudioStreamFormat.channels,
            AVLinearPCMBitDepthKey: AudioStreamFormat.bitsPerChannel,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        guard session.canAddOutput(output) else {
            throw AudioRecordingError.cannotAddOutput
        }
        session.addOutput(output)

        let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: AudioStreamFormat.sampleRate,
            AVNumberOfChannelsKey: AudioStreamFormat.channels,
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
        let writerInputBox = writerInput.map(AssetWriterInputBox.init)
        let didWriteAudio = didStartWriting
        // stopCaptureOnly 会先摘掉采集 delegate，之后不再有新的音频帧入队。
        stopCaptureOnly()

        // 收尾派发到 captureQueue 末尾：借串行队列的 FIFO 顺序，
        // 保证任何在途 append 先执行完，杜绝「markAsFinished 之后又 append」
        // 触发的写入报错——正是这个竞态导致停止成功却误报「停止录音失败」。
        captureQueue.async {
            guard didWriteAudio else {
                writerBox?.writer.cancelWriting()
                NSLog("录音停止：尚未收到音频帧，跳过音频文件收尾。")
                completion(.success(()))
                return
            }

            writerInputBox?.input.markAsFinished()
            writerBox?.writer.finishWriting {
                if let error = writerBox?.writer.error {
                    completion(.failure(AudioRecordingError.writerFailed(error.localizedDescription)))
                } else {
                    completion(.success(()))
                }
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
        onAudioFrame = nil
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

private final class AssetWriterInputBox: @unchecked Sendable {
    let input: AVAssetWriterInput

    init(input: AVAssetWriterInput) {
        self.input = input
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
        emitAudioFrame(from: sampleBuffer)

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

    private func emitAudioFrame(from sampleBuffer: CMSampleBuffer) {
        guard let onAudioFrame,
              let format = CMSampleBufferGetFormatDescription(sampleBuffer),
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(format),
              let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return
        }

        let length = CMBlockBufferGetDataLength(dataBuffer)
        guard length > 0 else { return }

        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return OSStatus(paramErr)
            }

            return CMBlockBufferCopyDataBytes(
                dataBuffer,
                atOffset: 0,
                dataLength: length,
                destination: baseAddress
            )
        }

        guard result == kCMBlockBufferNoErr else { return }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let milliseconds = Int(CMTimeGetSeconds(timestamp) * 1000)
        let frame = AudioFrame(
            data: data,
            sampleRate: normalizedSampleRate(streamDescription.pointee.mSampleRate),
            channels: normalizedChannels(streamDescription.pointee.mChannelsPerFrame),
            bitsPerChannel: normalizedBitsPerChannel(streamDescription.pointee.mBitsPerChannel),
            timestampMilliseconds: milliseconds
        )
        onAudioFrame(frame)
    }

    private func normalizedSampleRate(_ value: Float64) -> Int {
        value > 0 ? Int(value) : AudioStreamFormat.sampleRate
    }

    private func normalizedChannels(_ value: UInt32) -> Int {
        value > 0 ? Int(value) : AudioStreamFormat.channels
    }

    private func normalizedBitsPerChannel(_ value: UInt32) -> Int {
        value > 0 ? Int(value) : AudioStreamFormat.bitsPerChannel
    }
}

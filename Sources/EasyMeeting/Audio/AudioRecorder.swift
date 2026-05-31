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

        let device = try Self.captureDevice(id: selectedDeviceID)
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
            AVEncoderBitRateKey: AudioStreamFormat.aacEncoderBitRate
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

    /// 会议进行中热切换麦克风：在 captureQueue 上事务式替换 AVCaptureSession 的 input，
    /// 不触碰 output / delegate / onAudioFrame / writer，下游识别与录音文件连续不断。
    /// AVCaptureSession.inputs 自身即当前 input 的事实来源，无需在外另存引用；
    /// 整个临界区在 captureQueue 上串行执行，既与音频帧 append 互不交叉，
    /// 也避免快速连点导致的双重替换竞态。详见 docs/audio-hot-swap.md。
    func switchDevice(
        to selectedDeviceID: String?,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        guard isRecording, let session else {
            completion(.failure(AudioRecordingError.notRecording))
            return
        }

        let sessionBox = CaptureSessionBox(session: session)
        let deviceID = selectedDeviceID

        captureQueue.async {
            let session = sessionBox.session
            guard let oldInput = session.inputs.first as? AVCaptureDeviceInput else {
                completion(.failure(AudioRecordingError.notRecording))
                return
            }

            let newInput: AVCaptureDeviceInput
            do {
                let device = try Self.captureDevice(id: deviceID)
                // 已是同一设备则无需切换，避免无谓的事务与瞬时静音。
                if device.uniqueID == oldInput.device.uniqueID {
                    completion(.success(()))
                    return
                }
                newInput = try AVCaptureDeviceInput(device: device)
            } catch {
                NSLog("[麦克风切换] 创建新输入失败，session 保持不动：%@", error.localizedDescription)
                completion(.failure(error))
                return
            }

            session.beginConfiguration()
            session.removeInput(oldInput)

            if session.canAddInput(newInput) {
                session.addInput(newInput)
                session.commitConfiguration()
                NSLog("[麦克风切换] 成功切换到设备：%@", newInput.device.localizedName)
                completion(.success(()))
            } else {
                // 新设备无法加入，回滚旧 input 保证录音继续。
                session.addInput(oldInput)
                session.commitConfiguration()
                NSLog("[麦克风切换] 新设备无法加入，已回滚旧设备。")
                completion(.failure(AudioRecordingError.cannotAddInput))
            }
        }
    }

    func stopRecording(completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        guard isRecording else {
            // isRecording 在正常停止前被置 false，通常意味着录音过程中 writer 已失败
            // （见 append 中的 failed 分支日志）。这里返回 notRecording 让上层据实报错。
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
        // 保证任何在途 append 先执行完，杜绝「markAsFinished 之后又 append」触发的写入报错。
        captureQueue.async {
            guard didWriteAudio else {
                writerBox?.writer.cancelWriting()
                NSLog("[录音停止] 尚未收到音频帧，跳过音频文件收尾，按成功处理。")
                completion(.success(()))
                return
            }

            writerInputBox?.input.markAsFinished()
            writerBox?.writer.finishWriting {
                if let error = writerBox?.writer.error {
                    let nsError = error as NSError
                    NSLog(
                        "[录音停止] finishWriting 失败。domain=%@ code=%ld desc=%@",
                        nsError.domain, nsError.code, nsError.localizedDescription
                    )
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

    private static func captureDevice(id selectedDeviceID: String?) throws -> AVCaptureDevice {
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
            if isRecording {
                let nsError = writer.error as NSError?
                NSLog(
                    "[录音写入] 录音过程中 writer 进入 failed，停止追加。domain=%@ code=%ld desc=%@",
                    nsError?.domain ?? "nil",
                    nsError?.code ?? 0,
                    nsError?.localizedDescription ?? "nil"
                )
            }
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

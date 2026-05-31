@preconcurrency import AVFoundation

/// 跨线程传递 AVFoundation 对象的轻量包装。
///
/// AVAssetWriter / AVAssetWriterInput / AVCaptureSession 均非 Sendable，
/// 但录音收尾与麦克风热切换都需要把它们派发到 captureQueue 串行执行。
/// 这里用 @unchecked Sendable 显式承诺：同一对象只在 captureQueue 上被访问，
/// 借串行队列的 FIFO 顺序保证不存在并发访问。
final class AssetWriterBox: @unchecked Sendable {
    let writer: AVAssetWriter

    init(writer: AVAssetWriter) {
        self.writer = writer
    }
}

final class AssetWriterInputBox: @unchecked Sendable {
    let input: AVAssetWriterInput

    init(input: AVAssetWriterInput) {
        self.input = input
    }
}

final class CaptureSessionBox: @unchecked Sendable {
    let session: AVCaptureSession

    init(session: AVCaptureSession) {
        self.session = session
    }
}

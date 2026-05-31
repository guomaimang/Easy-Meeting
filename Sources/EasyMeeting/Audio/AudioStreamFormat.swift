import Foundation

enum AudioStreamFormat {
    static let sampleRate = 16_000
    static let channels = 1
    static let bitsPerChannel = 16

    /// 录音落盘的 AAC 编码码率。
    ///
    /// 注意：AAC 在不同采样率 / 声道数下有各自的合法码率区间。
    /// 16kHz 单声道的合法上限为 48kbps，超出会触发编码器报
    /// `-11861 Cannot Encode Media`，导致录音中途写入失败。
    /// 32kbps 对 16kHz 单声道语音已足够清晰，且留有余量。
    static let aacEncoderBitRate = 32_000
}

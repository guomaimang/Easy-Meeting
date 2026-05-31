import Foundation

struct AudioFrame: Sendable {
    let data: Data
    let sampleRate: Int
    let channels: Int
    let bitsPerChannel: Int
    let timestampMilliseconds: Int
}

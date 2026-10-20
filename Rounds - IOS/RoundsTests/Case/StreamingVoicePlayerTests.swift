import AVFoundation
import Foundation
import Testing
@testable import Rounds

/// The streamed voice arrives as raw 16-bit PCM; these check the conversion the player schedules.
struct StreamingVoicePlayerTests {
    private let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 24_000, channels: 1, interleaved: false)!

    @Test func littleEndianSamplesBecomeFloats() throws {
        // 0, +max, -max as little-endian Int16.
        let bytes = Data([0x00, 0x00, 0xFF, 0x7F, 0x01, 0x80])
        let buffer = try #require(StreamingVoicePlayer.buffer(from: bytes, format: format))
        #expect(buffer.frameLength == 3)
        let samples = buffer.floatChannelData![0]
        #expect(samples[0] == 0)
        #expect(samples[1] == 1)
        #expect(samples[2] == -1)
    }

    @Test func silenceIsQuietAndFullScaleIsLoud() throws {
        let silent = try #require(StreamingVoicePlayer.buffer(from: Data(count: 960), format: format))
        #expect(StreamingVoicePlayer.loudness(silent) == 0)
        let loud = try #require(StreamingVoicePlayer.buffer(from: Data((0..<480).flatMap { _ in [UInt8(0xFF), 0x7F] }), format: format))
        #expect(StreamingVoicePlayer.loudness(loud) == 1)
    }
}

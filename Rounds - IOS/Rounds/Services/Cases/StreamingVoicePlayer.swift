import AVFoundation
import Foundation

/// Plays the patient's voice while it's still arriving: raw PCM chunks (24 kHz, 16-bit, mono) from
/// `case-session` `speak_stream` are scheduled on an audio engine as they land, so the first word
/// sounds about a second sooner than waiting for a whole file.
@MainActor
final class StreamingVoicePlayer {
    static let sampleRate: Double = 24_000

    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    /// Speeds the voice up or down (Settings › voice speed) without changing its pitch.
    private let speed = AVAudioUnitTimePitch()
    private let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)
    /// Buffers scheduled but not yet heard, and who's waiting for the last one.
    private var pending = 0
    private var drained: CheckedContinuation<Void, Never>?
    private var stopped = false
    /// Each scheduled chunk's first frame and loudness, so the orb follows what's audible now rather
    /// than what just arrived (chunks land faster than they play).
    private var loudnessByFrame: [(start: Int64, level: CGFloat)] = []
    private var scheduledFrames: Int64 = 0

    init() {
        engine.attach(node)
        engine.attach(speed)
        engine.connect(node, to: speed, format: format)
        engine.connect(speed, to: engine.mainMixerNode, format: format)
    }

    /// Loudness (0…1) of what's playing right now, for the orb.
    var currentLevel: CGFloat {
        guard let renderTime = node.lastRenderTime, let time = node.playerTime(forNodeTime: renderTime) else { return 0 }
        return loudnessByFrame.last(where: { $0.start <= time.sampleTime })?.level ?? 0
    }

    /// Plays the stream to its end. `started` fires with the first audio. Throws if the stream fails
    /// before any audio, so the caller can fall back; once audio has played, a failure just ends the
    /// reply early.
    func play(_ stream: AsyncThrowingStream<Data, Error>, rate: Float, started: () -> Void) async throws {
        guard let format else { throw CaseServiceError(message: "Audio format unavailable.") }
        stopped = false
        speed.rate = rate
        try engine.start()
        node.play()
        var leftover = Data()
        var heard = false
        do {
            for try await chunk in stream {
                if stopped { break }
                leftover.append(chunk)
                // 16-bit samples: keep an odd trailing byte for the next chunk.
                let usable = leftover.count - leftover.count % 2
                guard usable > 0, let buffer = Self.buffer(from: leftover.prefix(usable), format: format) else { continue }
                leftover.removeFirst(usable)
                loudnessByFrame.append((scheduledFrames, Self.loudness(buffer)))
                scheduledFrames += Int64(buffer.frameLength)
                schedule(buffer)
                if !heard { heard = true; started() }
            }
        } catch {
            if !heard { stop(); throw error }
        }
        if !stopped { await drain() }
        stop()
    }

    func stop() {
        stopped = true
        node.stop()
        engine.stop()
        pending = 0
        loudnessByFrame = []
        scheduledFrames = 0
        drained?.resume(); drained = nil
    }

    private func schedule(_ buffer: AVAudioPCMBuffer) {
        pending += 1
        node.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in self?.played() }
        }
    }

    private func played() {
        pending = max(0, pending - 1)
        if pending == 0 { drained?.resume(); drained = nil }
    }

    /// Waits until every scheduled buffer has been heard.
    private func drain() async {
        guard pending > 0 else { return }
        await withCheckedContinuation { drained = $0 }
    }

    /// Little-endian 16-bit samples as a float buffer the engine can play.
    nonisolated static func buffer(from bytes: Data, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frames = bytes.count / 2
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
              let out = buffer.floatChannelData?[0] else { return nil }
        bytes.withUnsafeBytes { raw in
            for i in 0..<frames {
                let sample = Int16(littleEndian: raw.loadUnaligned(fromByteOffset: i * 2, as: Int16.self))
                out[i] = Float(sample) / Float(Int16.max)
            }
        }
        buffer.frameLength = AVAudioFrameCount(frames)
        return buffer
    }

    /// RMS loudness mapped to 0…1 the same way the mic level is (−50 dB → 0, −10 dB → 1).
    nonisolated static func loudness(_ buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        let n = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<n { sum += data[i] * data[i] }
        let db = 20 * log10(max(sqrt(sum / Float(n)), 1e-7))
        return CGFloat(min(max((db + 50) / 40, 0), 1))
    }
}

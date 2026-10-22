import AVFoundation

/// A microphone buffer's loudness as 0…1 for drawing: its RMS in decibels, mapped from `floorDb`
/// (silence, 0) across `rangeDb` (full, 1).
func micLevel(_ buffer: AVAudioPCMBuffer, floorDb: Float = -50, rangeDb: Float = 40) -> CGFloat {
    guard let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
    let n = Int(buffer.frameLength)
    var sum: Float = 0
    for i in 0..<n { sum += data[i] * data[i] }
    let rms = sqrt(sum / Float(n))
    let db = 20 * log10(max(rms, 1e-7))
    return CGFloat(min(max((db - floorDb) / rangeDb, 0), 1))
}

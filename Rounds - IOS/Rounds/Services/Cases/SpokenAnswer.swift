import Foundation

/// The patient's answer to a spoken question: the reply (shown at once) and its voice, streamed as
/// raw PCM (24 kHz, 16-bit, mono) right behind it in the same response.
struct SpokenAnswer: Sendable {
    let answer: PatientAnswer
    let audio: AsyncThrowingStream<Data, Error>
}

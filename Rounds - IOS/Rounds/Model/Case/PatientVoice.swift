import AVFoundation

/// Which iOS voice a patient speaks with. iOS's plain "en-US" voice is the compact, robotic one;
/// the Enhanced and Premium voices sound natural but exist only once the user downloads them
/// (Settings › Accessibility › Spoken Content › Voices). So the best installed quality wins, the
/// voice matches the patient's sex when one does, and the same patient always gets the same voice.
enum PatientVoice {
    /// A voice as the picker sees it, so the rules are testable without the installed voices.
    struct Candidate: Equatable {
        enum Gender { case male, female, unspecified }
        let identifier: String
        let language: String
        /// 1 compact, 2 enhanced, 3 premium (AVSpeechSynthesisVoiceQuality's raw values).
        let quality: Int
        let gender: Gender
    }

    /// Lowest quality that doesn't sound robotic.
    static let naturalQuality = 2
    /// Children have no voice of their own on iOS; a slightly raised pitch reads younger.
    static let childPitch: Float = 1.12
    static let childAge = 13

    /// The voice for a patient: US English first, then any English; best quality; the patient's
    /// sex when a voice of that quality has it; then chosen by `seed` (the bed code) so it's stable.
    static func pick(from voices: [Candidate], sex: String, seed: String) -> String? {
        let english = voices.filter { $0.language.hasPrefix("en") }
        let pool = english.contains { $0.language == "en-US" } ? english.filter { $0.language == "en-US" } : english
        guard let best = pool.map(\.quality).max() else { return nil }
        let top = pool.filter { $0.quality == best }
        let wanted = gender(of: sex)
        let matching = top.filter { $0.gender == wanted }
        let choices = (matching.isEmpty ? top : matching).sorted { $0.identifier < $1.identifier }
        let index = seed.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF } % choices.count
        return choices[index].identifier
    }

    /// Pitch for the patient's age: raised for children, natural otherwise.
    static func pitch(age: Int) -> Float { age < childAge ? childPitch : 1 }

    /// True when an Enhanced or Premium English voice is installed, so patients won't sound robotic.
    static func hasNaturalVoice(in voices: [Candidate] = installed()) -> Bool {
        voices.contains { $0.language.hasPrefix("en") && $0.quality >= naturalQuality }
    }

    /// The device's voices, without novelty voices (Bubbles, Bells…) and the user's Personal Voice.
    static func installed() -> [Candidate] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { !$0.voiceTraits.contains(.isNoveltyVoice) && !$0.voiceTraits.contains(.isPersonalVoice) }
            .map { voice in
                Candidate(identifier: voice.identifier, language: voice.language, quality: voice.quality.rawValue,
                          gender: voice.gender == .male ? .male : voice.gender == .female ? .female : .unspecified)
            }
    }

    private static func gender(of sex: String) -> Candidate.Gender {
        switch sex.lowercased().prefix(1) {
        case "m": .male
        case "f": .female
        default: .unspecified
        }
    }
}

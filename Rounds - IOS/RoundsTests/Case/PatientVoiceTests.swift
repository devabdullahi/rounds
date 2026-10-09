import Testing
@testable import Rounds

@Suite("Patient voice")
struct PatientVoiceTests {
    private typealias Voice = PatientVoice.Candidate
    private let voices = [
        Voice(identifier: "compact.samantha", language: "en-US", quality: 1, gender: .female),
        Voice(identifier: "enhanced.evan", language: "en-US", quality: 2, gender: .male),
        Voice(identifier: "premium.ava", language: "en-US", quality: 3, gender: .female),
        Voice(identifier: "premium.zoe", language: "en-US", quality: 3, gender: .female),
        Voice(identifier: "premium.serena", language: "en-GB", quality: 3, gender: .female),
        Voice(identifier: "premium.thomas", language: "fr-FR", quality: 3, gender: .male),
    ]

    @Test func bestQualityBeatsMatchingSex() {
        // No premium US male voice: a premium female voice beats the enhanced male one.
        let id = PatientVoice.pick(from: voices, sex: "M", seed: "PF284")
        #expect(id == "premium.ava" || id == "premium.zoe")
    }

    @Test func matchesSexWithinTheBestQuality() {
        let withMale = voices + [Voice(identifier: "premium.nathan", language: "en-US", quality: 3, gender: .male)]
        #expect(PatientVoice.pick(from: withMale, sex: "M", seed: "AB123") == "premium.nathan")
    }

    @Test func samePatientSameVoice() {
        let first = PatientVoice.pick(from: voices, sex: "F", seed: "KX902")
        #expect(PatientVoice.pick(from: voices.reversed(), sex: "F", seed: "KX902") == first)
    }

    @Test func fallsBackToOtherEnglishThenNothing() {
        let british = [Voice(identifier: "premium.serena", language: "en-GB", quality: 3, gender: .female)]
        #expect(PatientVoice.pick(from: british, sex: "F", seed: "A") == "premium.serena")
        #expect(PatientVoice.pick(from: [voices[5]], sex: "M", seed: "A") == nil)
    }

    @Test func naturalVoiceNeedsEnhancedEnglish() {
        #expect(!PatientVoice.hasNaturalVoice(in: [voices[0], voices[5]]))
        #expect(PatientVoice.hasNaturalVoice(in: [voices[1]]))
    }

    @Test(arguments: [(8, PatientVoice.childPitch), (12, PatientVoice.childPitch), (13, 1), (70, 1)] as [(Int, Float)])
    func childrenSpeakHigher(age: Int, pitch: Float) {
        #expect(PatientVoice.pitch(age: age) == pitch)
    }
}

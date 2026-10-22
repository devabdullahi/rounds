import Foundation
import Testing
@testable import Rounds

struct OnboardingAnswersTests {
    private func defaults() -> UserDefaults {
        let name = "OnboardingAnswersTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func readsThePicksOnboardingStored() {
        let d = defaults()
        d.set("ms3", forKey: SchoolYear.storageKey)
        d.set("", forKey: StudyGoal.storageKey)
        d.set("timing,whatToAsk", forKey: StudyStruggle.storageKey)
        d.set(false, forKey: Preferences.voiceModeKey)
        d.set(3, forKey: DailyGoal.storageKey)
        d.set("evening", forKey: PracticeReminder.storageKey)
        let answers = OnboardingAnswers.stored(in: d)
        #expect(answers.schoolYear == "ms3")
        #expect(answers.studyGoal == nil)
        #expect(answers.struggles == ["whatToAsk", "timing"])
        #expect(answers.voiceMode == false)
        #expect(answers.dailyGoal == 3)
        #expect(answers.reminder == "evening")
        #expect(answers.timeLimitMinutes == TimeLimit.defaultMinutes)
    }
}

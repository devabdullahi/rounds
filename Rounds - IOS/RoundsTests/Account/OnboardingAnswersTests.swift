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
        let answers = OnboardingAnswers.stored(in: d, redFlagPick: nil)
        #expect(answers.schoolYear == "ms3")
        #expect(answers.studyGoal == nil)
        #expect(answers.struggles == ["whatToAsk", "timing"])
        #expect(answers.voiceMode == false)
        #expect(answers.dailyGoal == 3)
        #expect(answers.reminder == "evening")
        #expect(answers.timeLimitMinutes == TimeLimit.defaultMinutes)
    }

    @Test func savesWhyTheyDownloadedRounds() {
        let d = defaults()
        #expect(OnboardingAnswers.stored(in: d, redFlagPick: nil).downloadReason == nil)
        d.set(DownloadReason.differentials.rawValue, forKey: DownloadReason.storageKey)
        let answers = OnboardingAnswers.stored(in: d, redFlagPick: nil)
        #expect(answers.downloadReason == "differentials")
        #expect(OnboardingAnswersRow(userID: UUID(), answers: answers, appVersion: "1").download_reason == "differentials")
    }

    /// The quiz pick is saved as the option's place and whether it was the red flag.
    @Test(arguments: RedFlagQuiz.chestPain.options.indices)
    func recordsTheQuizPick(index: Int) {
        let option = RedFlagQuiz.chestPain.options[index]
        let answers = OnboardingAnswers.stored(in: defaults(), redFlagPick: option.id)
        #expect(answers.redFlagPick == index)
        #expect(answers.redFlagCorrect == option.isRedFlag)
    }

    @Test func noQuizPickLeavesItEmpty() {
        let answers = OnboardingAnswers.stored(in: defaults(), redFlagPick: nil)
        #expect(answers.redFlagPick == nil)
        #expect(answers.redFlagCorrect == nil)
    }

    @Test func startingOverClearsTheQuestionPicksOnly() {
        let d = defaults()
        d.set("ms3", forKey: SchoolYear.storageKey)
        d.set("step2CK", forKey: StudyGoal.storageKey)
        d.set("2026-12", forKey: ExamMonth.storageKey)
        d.set("friend", forKey: HeardFrom.storageKey)
        d.set(false, forKey: Preferences.voiceModeKey)
        OnboardingAnswers.clearPicks(in: d)
        let answers = OnboardingAnswers.stored(in: d, redFlagPick: nil)
        #expect(answers.schoolYear == nil)
        #expect(answers.studyGoal == nil)
        #expect(d.string(forKey: ExamMonth.storageKey) == nil)
        #expect(d.string(forKey: HeardFrom.storageKey) == nil)
        #expect(answers.voiceMode == false)
    }
}

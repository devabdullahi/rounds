import Foundation
import Testing
@testable import Rounds

/// What onboarding stored becomes what a submission sends.
struct GradingFocusTests {
    private func defaults() -> UserDefaults {
        let name = "GradingFocusTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func readsTheGoalAndStrugglesOnboardingStored() {
        let d = defaults()
        d.set("step2CK", forKey: StudyGoal.storageKey)
        d.set("tests,whatToAsk,bogus", forKey: StudyStruggle.storageKey)
        let focus = GradingFocus.stored(in: d)
        #expect(focus.goal == .step2CK)
        #expect(focus.struggleValues == ["whatToAsk", "tests"])
    }

    @Test func nothingStoredSendsNothing() {
        let focus = GradingFocus.stored(in: defaults())
        #expect(focus.goal == nil)
        #expect(focus.struggleValues.isEmpty)
    }
}

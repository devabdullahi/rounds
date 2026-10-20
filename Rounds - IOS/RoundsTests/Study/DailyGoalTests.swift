import Testing
@testable import Rounds

struct DailyGoalTests {
    @Test(arguments: [(0, DailyGoal.two), (1, .one), (5, .five), (4, .two)])
    func storedValueReadsBackOrDefaults(stored: Int, goal: DailyGoal) {
        #expect(DailyGoal(stored: stored) == goal)
    }

    @Test func labelsReadNaturally() {
        #expect(DailyGoal.one.label == "1 case")
        #expect(DailyGoal.three.label == "3 cases")
        #expect(DailyGoal.three.duration == "About 30 min")
    }
}

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

    @Test func stepsThroughThePacesAndStopsAtTheEnds() {
        #expect(DailyGoal.two.stepped(by: 1) == .three)
        #expect(DailyGoal.three.stepped(by: 1) == .five)
        #expect(DailyGoal.two.stepped(by: -1) == .one)
        #expect(DailyGoal.one.stepped(by: -1) == nil)
        #expect(DailyGoal.five.stepped(by: 1) == nil)
    }
}

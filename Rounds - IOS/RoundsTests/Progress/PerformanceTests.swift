import Foundation
import Testing
@testable import Rounds

@Suite("Where you lose points")
struct PerformanceTests {
    private let recent = graded("a", daysAgo: 2, breakdown: [.history: Points(got: 10, max: 25), .exam: Points(got: 15, max: 15)])
    private let older = graded("b", daysAgo: 20, breakdown: [.history: Points(got: 25, max: 25), .exam: Points(got: 0, max: 15)])

    @Test func weakestShareComesFirst() {
        let (stats, cases) = Performance.stats([recent], in: .week, now: now)
        #expect(cases == 1)
        #expect(stats.map(\.category) == [.history, .exam])
        #expect(stats.first?.lost == 15)
    }

    @Test(arguments: [(Timeframe.week, 1), (.month, 2), (.all, 2)])
    func timeframeLimitsTheCases(timeframe: Timeframe, expected: Int) {
        #expect(Performance.stats([recent, older], in: timeframe, now: now).cases == expected)
    }

    @Test func totalsAddAcrossCases() {
        let history = Performance.stats([recent, older], in: .all, now: now).stats.first { $0.category == .history }
        #expect(history?.points == Points(got: 35, max: 50))
    }

    @Test func casesWithoutABreakdownAreLeftOut() {
        let (stats, cases) = Performance.stats([graded("old", daysAgo: 1)], in: .all, now: now)
        #expect(cases == 0)
        #expect(stats.isEmpty)
    }
}

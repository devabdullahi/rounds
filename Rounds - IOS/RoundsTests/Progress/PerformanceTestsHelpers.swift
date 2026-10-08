import Foundation
import Testing
@testable import Rounds

let now = Date(timeIntervalSince1970: 1_800_000_000)

func graded(_ id: String, daysAgo: Double, score: Int = 70, correct: Bool = true, missed: Int = 0,
                    clerkship: Clerkship? = .internalMedicine, system: OrganSystem? = .cardiovascular,
                    breakdown: [ScoreCategory: Points] = [:]) -> GradedCase {
    GradedCase(id: id, submittedAt: now.addingTimeInterval(-daysAgo * 86_400), score: score, diagnosisCorrect: correct,
               missedRedFlags: missed, clerkship: clerkship, system: system, breakdown: breakdown)
}

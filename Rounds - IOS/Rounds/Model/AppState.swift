import SwiftUI
import Observation

/// Career-level progress that outlives a single case.
@Observable
final class AppState {
    var rating = 1482
    var streak = 12
    var patientsSeen = 216
    var rightDiagnosisRate = 0.71
    var bestStreak = 19
    var redFlagRate = 0.72
    var rotationDone = 9
    let rotationTotal = 20
    /// Per-patient: what you missed last time you saw them. Empty → nothing to revisit.
    var misses: [String: [Miss]] = Ward.seededMisses
    var lastScores: [String: Int] = Ward.seededScores

    var totalMisses: Int { misses.values.reduce(0) { $0 + $1.count } }
    var revisitPatients: [WardPatient] { Ward.revisit.filter { !(misses[$0.id] ?? []).isEmpty } }

    var lastGrade: Grade?
    var activeCase: CaseSession?
    var debugInitialPath: [CaseStep] = []

    static let fellowThreshold = 1600
    static let residentFloor = 1200

    var tierProgress: Double {
        Double(rating - Self.residentFloor) / Double(Self.fellowThreshold - Self.residentFloor)
    }
    var toNextTier: Int { max(0, Self.fellowThreshold - rating) }

    func startCase() {
        activeCase = CaseSession()
    }

    func record(_ grade: Grade, patient: String) {
        lastGrade = grade
        misses[patient] = grade.missedRedFlags
        lastScores[patient] = grade.score
        rating += grade.ratingDelta
        patientsSeen += 1
        rotationDone = min(rotationTotal, rotationDone + 1)
    }
}

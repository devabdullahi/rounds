import SwiftUI

/// "Great choice": right after the year and goal, the student's picks read back as tags, and what
/// grading will look like for them. Only answers they gave appear here.
struct GradedForYouPage: View {
    var shown = true
    @AppStorage(SchoolYear.storageKey) private var yearStored = ""
    @AppStorage(StudyGoal.storageKey) private var goalStored = ""

    private var year: SchoolYear? { SchoolYear(stored: yearStored) }
    private var goal: StudyGoal? { StudyGoal(stored: goalStored) }
    private var isExam: Bool { [.step1, .step2CK, .shelf, .osce].contains(goal) }

    private var title: String {
        guard let goal, isExam else { return "Great choice. Every case is graded like an attending would." }
        return goal == .shelf ? "Great choice. Every debrief has tips for your shelves." : "Great choice. Every debrief has \(tipsName) tips."
    }

    private var tipsName: String { goal?.tipsName ?? "Exam" }

    private var rows: [(IconGlyph, String, String)] {
        [
            // Only what the app really does: the exam lens in each debrief, the same full grading
            // for everyone, and cards from misses. No claims about case level or schedule yet.
            goal?.debriefTips.map { (.user, "\(tipsName) tips in every debrief", $0) }
                ?? (.user, "An attending's feedback", "What went well, and what to fix"),
            (.check, "Graded on the whole workup", "History, exam, tests, diagnosis"),
            (.cards, "Turn your misses into cards", isExam ? "Review them before test day" : "Review them any time"),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                ForEach([year?.label, goal?.label].compactMap { $0 }, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.accentText)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Theme.accentSoft, in: Capsule())
                }
            }
            .modifier(QuestionEntrance(order: 0))
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .modifier(QuestionEntrance(order: 1))
            VStack(spacing: 10) {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    HStack(spacing: 14) {
                        AppIcon(row.0, size: 20)
                            .foregroundStyle(Theme.accentText)
                            .frame(width: 40, height: 40)
                            .background(Theme.surface, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.1).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.text)
                            Text(row.2).font(.system(size: 14)).foregroundStyle(Theme.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(Theme.track, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityElement(children: .combine)
                    .modifier(QuestionEntrance(order: i + 2))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }
}

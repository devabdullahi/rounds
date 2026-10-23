import SwiftUI

/// "When do you study best?": the time the reminder screen offers later. Saved as a preference
/// only; it becomes a reminder when the student allows notifications.
struct StudyTimePage: View {
    var shown = true
    @AppStorage(PracticeReminder.preferredKey) private var stored = ""

    private static let details: [PracticeReminder: String] = [
        .morning: "Before class or rounds", .lunch: "Between lectures", .evening: "After the wards", .lateNight: "When it's quiet",
    ]
    private static let glyphs: [PracticeReminder: IconGlyph] = [.morning: .compass, .lunch: .clock, .evening: .bell, .lateNight: .moon]

    var body: some View {
        OnboardingQuestion(title: "When do you study best?", shown: shown) {
            ForEach(Array(PracticeReminder.allCases.enumerated()), id: \.element) { i, time in
                ChoiceRow(title: time.period, detail: Self.details[time], glyph: Self.glyphs[time], tint: ChoiceRow.tint(i),
                          on: stored == time.rawValue, order: i) { stored = time.rawValue }
            }
        }
    }
}

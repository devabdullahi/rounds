import SwiftUI

/// "What year are you in?": MS1–MS4, one tap picks.
struct SchoolYearPage: View {
    var shown = true
    @AppStorage(SchoolYear.storageKey) private var stored = ""

    private static let detail: [SchoolYear: String] = [
        .ms1: "Foundations", .ms2: "Step 1 year", .ms3: "Core clerkships", .ms4: "Sub-Is and electives",
    ]

    var body: some View {
        OnboardingQuestion(title: "What year are you in?", shown: shown) {
            ForEach(Array(SchoolYear.allCases.enumerated()), id: \.element) { i, year in
                ChoiceRow(title: year.label, detail: Self.detail[year], badge: String(i + 1), tint: ChoiceRow.tint(i),
                          on: SchoolYear(stored: stored) == year, order: i) { stored = year.rawValue }
            }
        }
    }
}

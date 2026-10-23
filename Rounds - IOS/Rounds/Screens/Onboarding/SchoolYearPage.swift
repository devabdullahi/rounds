import SwiftUI

/// "What year are you in?": MS1–MS4, or "Just practicing" for everyone else. One tap picks.
struct SchoolYearPage: View {
    var shown = true
    @AppStorage(SchoolYear.storageKey) private var stored = ""

    private static let detail: [SchoolYear: String] = [
        .ms1: "Foundations", .ms2: "Step 1 year", .ms3: "Core clerkships", .ms4: "Sub-Is and electives",
        .practicing: "Resident, PA, NP or anyone else",
    ]

    var body: some View {
        OnboardingQuestion(title: "What year are you in?", shown: shown) {
            ForEach(Array(SchoolYear.allCases.enumerated()), id: \.element) { i, year in
                ChoiceRow(title: year.label, detail: Self.detail[year], glyph: year == .practicing ? .dice : nil,
                          badge: year == .practicing ? nil : String(i + 1),
                          on: SchoolYear(stored: stored) == year, order: i) { stored = year.rawValue }
            }
        }
    }
}

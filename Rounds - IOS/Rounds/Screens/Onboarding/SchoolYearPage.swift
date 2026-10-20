import SwiftUI

/// "What year are you in?": MS1–MS4, one tap picks.
struct SchoolYearPage: View {
    @AppStorage(SchoolYear.storageKey) private var stored = ""

    var body: some View {
        OnboardingQuestion(title: "What year are you in?") {
            ForEach(SchoolYear.allCases) { year in
                ChoiceRow(title: year.label, on: SchoolYear(stored: stored) == year) { stored = year.rawValue }
            }
        }
    }
}

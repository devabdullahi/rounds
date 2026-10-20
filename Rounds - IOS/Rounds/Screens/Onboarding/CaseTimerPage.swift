import SwiftUI

/// "Want a timer on each case?": the default case clock, shared with Settings and the door note.
struct CaseTimerPage: View {
    @AppStorage(TimeLimit.storageKey) private var minutes = TimeLimit.defaultMinutes

    private static let rows: [(Int, String, String)] = [
        (0, "No timer", "Take your time"),
        (10, "10 minutes", "Quick station"),
        (15, "15 minutes", "Like an OSCE"),
        (20, "20 minutes", "Extra room"),
    ]

    var body: some View {
        OnboardingQuestion(title: "Want a timer on each case?") {
            ForEach(Self.rows, id: \.0) { value, title, detail in
                ChoiceRow(title: title, trailing: detail, on: minutes == value) { minutes = value }
            }
        }
    }
}

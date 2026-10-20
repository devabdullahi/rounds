import SwiftUI

/// "Want a timer on each case?": the default case clock, shared with Settings and the door note.
struct CaseTimerPage: View {
    var shown = true
    @AppStorage(TimeLimit.storageKey) private var minutes = TimeLimit.defaultMinutes

    private static let rows: [(Int, String, String)] = [
        (0, "No timer", "Take your time"),
        (10, "10 minutes", "Quick station"),
        (15, "15 minutes", "Like an OSCE"),
        (20, "20 minutes", "Extra room"),
    ]

    var body: some View {
        OnboardingQuestion(title: "Want a timer on each case?", glyph: .timer, shown: shown) {
            ForEach(Array(Self.rows.enumerated()), id: \.element.0) { i, row in
                let (value, title, detail) = row
                ChoiceRow(title: title, trailing: detail, badge: value == 0 ? "–" : String(value), tint: ChoiceRow.tint(i),
                          on: minutes == value, order: i) { minutes = value }
            }
        }
    }
}

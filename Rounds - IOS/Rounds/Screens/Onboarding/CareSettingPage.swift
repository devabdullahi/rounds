import SwiftUI

/// "Where do you want to see patients?": clinic, hospital or both. Starts on what the study goal
/// set (OSCEs → clinic).
struct CareSettingPage: View {
    @AppStorage(CareSetting.storageKey) private var stored = ""

    private static let rows: [(CareSetting, String, String, IconGlyph)] = [
        (.clinic, "Clinic", "Office visits, like an OSCE", .stethoscope),
        (.hospital, "Hospital", "Ward, ED and ICU patients", .hospital),
        (.any, "Both", "A mix of office and hospital", .shuffle),
    ]

    var body: some View {
        OnboardingQuestion(title: "Where do you want to see patients?") {
            ForEach(Self.rows, id: \.0) { setting, title, detail, glyph in
                ChoiceRow(title: title, detail: detail, glyph: glyph, on: CareSetting(stored: stored) == setting) {
                    stored = setting.rawValue
                }
            }
        }
    }
}

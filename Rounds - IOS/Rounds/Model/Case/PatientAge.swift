import Foundation

/// A patient's age as the app shows it. Cases store whole years, so a baby under one is 0, which
/// reads like a bug next to a name.
enum PatientAge {
    static func label(_ years: Int) -> String {
        years < 1 ? "infant" : "\(years)"
    }
}

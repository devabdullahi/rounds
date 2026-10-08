import Foundation

struct Vital: Identifiable, Hashable {
    enum Tone { case accent, warn, info, plain }
    let id: String
    let label: String
    let value: String
    /// Outside the normal range, as flagged by the server.
    var isAbnormal = false

    /// Monitor colors by vital, matching the patient cards (HR green/blue, BP red, SpO₂ info).
    var tone: Tone {
        switch id {
        case "hr": .accent
        case "sbp", "bp": .warn
        case "spo2": .info
        default: .plain
        }
    }
}

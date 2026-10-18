import Foundation

/// Where an exam step belongs, in the order a clinician examines: overall look first, then vitals,
/// then head to toe. Cases list maneuvers in no particular order, so the workup groups them by
/// what their titles name; anything unrecognised falls under General.
enum ExamRegion: Int, CaseIterable, Comparable, Sendable {
    case general, vitals, headNeck, chest, abdomen, limbsSkin, neuro

    static func < (a: ExamRegion, b: ExamRegion) -> Bool { a.rawValue < b.rawValue }

    var label: String {
        switch self {
        case .general: "General"
        case .vitals: "Vitals"
        case .headNeck: "Head & neck"
        case .chest: "Chest"
        case .abdomen: "Abdomen"
        case .limbsSkin: "Limbs & skin"
        case .neuro: "Neuro"
        }
    }

    /// Checked in order, so "pulse oximetry" is a vital before "chest" can claim a word in it.
    private static let keywords: [(ExamRegion, [String])] = [
        (.vitals, ["respiratory rate", "heart rate", "blood pressure", "temperature", "pulse ox", "oxygen saturation", "spo2", "vital", "count the"]),
        (.neuro, ["neuro", "reflex", "cranial", "gait", "strength", "sensation", "coordination", "pupil", "mental status", "orientation", "fontanelle", "tone", "romberg", "speech", "alert", "responsive", "conscious", "cry"]),
        (.headNeck, ["head", "neck", "eye", "ear", "nose", "nasal", "throat", "mouth", "oral", "pharynx", "thyroid", "lymph", "jugular", "jvp", "tonsil", "sinus", "fundus", "otoscop", "trachea", "suprasternal", "airway"]),
        (.chest, ["chest", "lung", "breath", "heart", "cardiac", "auscultat", "precordi", "murmur", "respirat", "wheez", "retraction", "rib", "breast", "apex"]),
        (.abdomen, ["abdomen", "abdominal", "liver", "spleen", "bowel", "rectal", "pelvic", "groin", "hernia", "flank", "costovertebral", "cva", "umbilic", "genital", "scrotal", "testic"]),
        (.limbsSkin, ["skin", "rash", "leg", "arm", "limb", "extremit", "joint", "knee", "ankle", "foot", "feet", "hand", "wrist", "shoulder", "hip", "spine", "back", "edema", "pulses", "capillary refill", "calf", "nail", "wound", "lesion"]),
    ]

    /// Keywords match at the start of a word ("ear" finds "ears", not "heart" or "appearance").
    static func of(_ title: String) -> ExamRegion {
        let words = " " + title.lowercased().map { $0.isLetter || $0.isNumber ? $0 : " " }.reduce(into: "") { $0.append($1) }
        return keywords.first { _, keys in keys.contains { words.contains(" " + $0) } }?.0 ?? .general
    }

    /// Maneuvers grouped by region, regions in exam order, each keeping the case's own order.
    static func grouped(_ maneuvers: [ExamManeuver]) -> [(region: ExamRegion, maneuvers: [ExamManeuver])] {
        let byRegion = Dictionary(grouping: maneuvers) { of($0.title) }
        return allCases.compactMap { region in byRegion[region].map { (region, $0) } }
    }
}

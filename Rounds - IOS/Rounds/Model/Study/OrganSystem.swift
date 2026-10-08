import Foundation

enum OrganSystem: String, CaseIterable, Identifiable {
    case cardiovascular, respiratory, gastrointestinal, renal, nervous, endocrine, blood, musculoskeletal, reproductive, behavioral
    var id: String { rawValue }

    var label: String {
        switch self {
        case .cardiovascular: "Cardiovascular"
        case .respiratory: "Respiratory"
        case .gastrointestinal: "Gastrointestinal"
        case .renal: "Renal & urinary"
        case .nervous: "Nervous system"
        case .endocrine: "Endocrine"
        case .blood: "Blood & immune"
        case .musculoskeletal: "MSK & skin"
        case .reproductive: "Reproductive"
        case .behavioral: "Behavioral health"
        }
    }

    var examples: String {
        switch self {
        case .cardiovascular: "Chest pain, syncope"
        case .respiratory: "Cough, wheeze"
        case .gastrointestinal: "Abdominal pain, jaundice"
        case .renal: "Dysuria, swelling"
        case .nervous: "Headache, weakness"
        case .endocrine: "Thirst, weight change"
        case .blood: "Bruising, fever"
        case .musculoskeletal: "Joint pain, rashes"
        case .reproductive: "Pelvic pain, bleeding"
        case .behavioral: "Low mood, sleep"
        }
    }
}

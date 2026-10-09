import Foundation

enum OrganSystem: String, CaseIterable, Identifiable {
    case cardiovascular, respiratory, gastrointestinal, renal, nervous, endocrine, blood, musculoskeletal, reproductive, behavioral
    case skin, eye, ent, immune
    var id: String { rawValue }

    var label: String {
        switch self {
        case .cardiovascular: "Cardiovascular"
        case .respiratory: "Respiratory"
        case .gastrointestinal: "Gastrointestinal"
        case .renal: "Renal & urinary"
        case .nervous: "Nervous system"
        case .endocrine: "Endocrine"
        case .blood: "Blood"
        case .musculoskeletal: "Musculoskeletal"
        case .reproductive: "Reproductive"
        case .behavioral: "Behavioral health"
        case .skin: "Skin"
        case .eye: "Eye"
        case .ent: "Ear, nose & throat"
        case .immune: "Immune & allergy"
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
        case .musculoskeletal: "Joint pain, back pain"
        case .reproductive: "Pelvic pain, bleeding"
        case .behavioral: "Low mood, sleep"
        case .skin: "Rashes, lesions, itch"
        case .eye: "Red eye, blurry vision"
        case .ent: "Ear pain, sore throat, dizziness"
        case .immune: "Allergic reactions, recurrent infections"
        }
    }
}

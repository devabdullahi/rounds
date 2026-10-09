import AppIntents

/// A topic Siri and Shortcuts can name: every rotation and organ system, with the words students
/// actually say ("cardiology", "GI", "peds") as synonyms.
enum IntentTopic: String, AppEnum {
    case internalMedicine, surgery, pediatrics, obgyn, psychiatry, familyMedicine, neurology, emergency
    case clinicalPsychology, dermatology
    case cardiovascular, respiratory, gastrointestinal, renal, nervous, endocrine, blood, musculoskeletal
    case reproductive, behavioral

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Topic"

    static let caseDisplayRepresentations: [IntentTopic: DisplayRepresentation] = [
        .internalMedicine: DisplayRepresentation(title: "Internal medicine", synonyms: ["medicine", "IM"]),
        .surgery: DisplayRepresentation(title: "Surgery", synonyms: ["surgical"]),
        .pediatrics: DisplayRepresentation(title: "Pediatrics", synonyms: ["peds", "pediatric"]),
        .obgyn: DisplayRepresentation(title: "OB/GYN", synonyms: ["OB", "obstetrics", "gynecology", "OBGYN"]),
        .psychiatry: DisplayRepresentation(title: "Psychiatry", synonyms: ["psych"]),
        .familyMedicine: DisplayRepresentation(title: "Family medicine", synonyms: ["family med", "primary care"]),
        .neurology: DisplayRepresentation(title: "Neurology", synonyms: ["neuro"]),
        .emergency: DisplayRepresentation(title: "Emergency medicine", synonyms: ["emergency", "EM", "ER"]),
        .clinicalPsychology: DisplayRepresentation(title: "Clinical psychology", synonyms: ["psychology"]),
        .dermatology: DisplayRepresentation(title: "Dermatology", synonyms: ["derm", "skin"]),
        .cardiovascular: DisplayRepresentation(title: "Cardiovascular", synonyms: ["cardiology", "cardiac", "heart"]),
        .respiratory: DisplayRepresentation(title: "Respiratory", synonyms: ["pulmonology", "pulmonary", "lungs"]),
        .gastrointestinal: DisplayRepresentation(title: "Gastrointestinal", synonyms: ["GI", "gastroenterology", "gut"]),
        .renal: DisplayRepresentation(title: "Renal", synonyms: ["nephrology", "kidney"]),
        .nervous: DisplayRepresentation(title: "Nervous system", synonyms: ["nervous", "neurologic"]),
        .endocrine: DisplayRepresentation(title: "Endocrine", synonyms: ["endocrinology", "endo"]),
        .blood: DisplayRepresentation(title: "Blood", synonyms: ["hematology", "heme"]),
        .musculoskeletal: DisplayRepresentation(title: "Musculoskeletal", synonyms: ["MSK", "orthopedics", "ortho"]),
        .reproductive: DisplayRepresentation(title: "Reproductive", synonyms: ["reproductive system"]),
        .behavioral: DisplayRepresentation(title: "Behavioral", synonyms: ["behavioral health"]),
    ]

    /// The study focus this topic means in the app.
    var focus: StudyFocus {
        if let rotation = Clerkship(rawValue: rawValue) { return .rotation(rotation) }
        if let system = OrganSystem(rawValue: rawValue) { return .system(system) }
        return .mix
    }
}

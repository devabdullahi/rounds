import AppIntents

/// A topic Siri and Shortcuts can name: every specialty and organ system, with the words students
/// actually say ("cardiology", "GI", "peds") as synonyms.
enum IntentTopic: String, AppEnum {
    case internalMedicine, surgery, pediatrics, obgyn, psychiatry, familyMedicine, neurology, emergency
    case clinicalPsychology, dermatology
    case allergyImmunology, cardiology, endocrinology, geriatrics, hematologyOncology, infectiousDisease
    case nephrology, ophthalmology, orthopedicSurgery, otolaryngology, rehabilitation, rheumatology, urology
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
        .allergyImmunology: DisplayRepresentation(title: "Allergy and immunology", synonyms: ["allergy", "immunology", "allergies"]),
        .cardiology: DisplayRepresentation(title: "Cardiology", synonyms: ["cardio", "vascular", "cardiology and vascular"]),
        .endocrinology: DisplayRepresentation(title: "Endocrinology", synonyms: ["endo", "diabetes", "thyroid"]),
        .geriatrics: DisplayRepresentation(title: "Geriatrics", synonyms: ["geri", "elderly", "older adults"]),
        .hematologyOncology: DisplayRepresentation(title: "Hematology oncology", synonyms: ["heme onc", "oncology", "cancer"]),
        .infectiousDisease: DisplayRepresentation(title: "Infectious disease", synonyms: ["ID", "infections", "infectious"]),
        .nephrology: DisplayRepresentation(title: "Nephrology", synonyms: ["nephro", "kidney disease"]),
        .ophthalmology: DisplayRepresentation(title: "Ophthalmology", synonyms: ["optho", "eyes", "eye"]),
        .orthopedicSurgery: DisplayRepresentation(title: "Orthopedic surgery", synonyms: ["ortho", "orthopedics"]),
        .otolaryngology: DisplayRepresentation(title: "Otolaryngology", synonyms: ["ENT", "ear nose and throat"]),
        .rehabilitation: DisplayRepresentation(title: "Physical medicine and rehab", synonyms: ["PM&R", "rehab", "rehabilitation"]),
        .rheumatology: DisplayRepresentation(title: "Rheumatology", synonyms: ["rheum", "rheumatology"]),
        .urology: DisplayRepresentation(title: "Urology", synonyms: ["uro", "urologic"]),
        .cardiovascular: DisplayRepresentation(title: "Cardiovascular", synonyms: ["cardiac", "heart", "circulation"]),
        .respiratory: DisplayRepresentation(title: "Respiratory", synonyms: ["pulmonology", "pulmonary", "lungs"]),
        .gastrointestinal: DisplayRepresentation(title: "Gastrointestinal", synonyms: ["GI", "gastroenterology", "gut"]),
        .renal: DisplayRepresentation(title: "Renal", synonyms: ["kidney", "kidneys"]),
        .nervous: DisplayRepresentation(title: "Nervous system", synonyms: ["nervous", "neurologic"]),
        .endocrine: DisplayRepresentation(title: "Endocrine system", synonyms: ["endocrine", "hormones"]),
        .blood: DisplayRepresentation(title: "Blood", synonyms: ["hematology", "heme"]),
        .musculoskeletal: DisplayRepresentation(title: "Musculoskeletal", synonyms: ["MSK", "muscles and bones"]),
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

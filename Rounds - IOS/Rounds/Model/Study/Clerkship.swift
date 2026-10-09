import Foundation

/// A specialty students practice by: the core clerkship rotations, then specialties added from the
/// condition catalog's tags (tools/kb-generate/tag_specialties.py). Raw values are what the server
/// stores in a condition's topic list and a case's specialty.
enum Clerkship: String, CaseIterable, Identifiable {
    case internalMedicine, surgery, pediatrics, obgyn, psychiatry, familyMedicine, neurology, emergency, clinicalPsychology, dermatology
    case allergyImmunology, cardiology, endocrinology, geriatrics, hematologyOncology, infectiousDisease
    case nephrology, ophthalmology, orthopedicSurgery, otolaryngology, rehabilitation, rheumatology, urology
    case neonatology, nutrition
    var id: String { rawValue }

    /// The core clerkship rotations, the original ten. Badges that ask for "every specialty" use these,
    /// so adding a specialty never makes a badge harder to earn.
    static let core: [Clerkship] = [.internalMedicine, .surgery, .pediatrics, .obgyn, .psychiatry, .familyMedicine,
                                    .neurology, .emergency, .clinicalPsychology, .dermatology]

    var label: String {
        switch self {
        case .internalMedicine: "Internal medicine"
        case .surgery: "Surgery"
        case .pediatrics: "Pediatrics"
        case .obgyn: "OB/GYN"
        case .psychiatry: "Psychiatry"
        case .familyMedicine: "Family medicine"
        case .neurology: "Neurology"
        case .emergency: "Emergency medicine"
        case .clinicalPsychology: "Clinical psychology"
        case .dermatology: "Dermatology"
        case .allergyImmunology: "Allergy & immunology"
        case .cardiology: "Cardiology & vascular"
        case .endocrinology: "Endocrinology"
        case .geriatrics: "Geriatrics"
        case .hematologyOncology: "Hematology/oncology"
        case .infectiousDisease: "Infectious disease"
        case .nephrology: "Nephrology"
        case .ophthalmology: "Ophthalmology"
        case .orthopedicSurgery: "Orthopedic surgery"
        case .otolaryngology: "Otolaryngology"
        case .rehabilitation: "Physical medicine & rehab"
        case .rheumatology: "Rheumatology"
        case .urology: "Urology"
        case .neonatology: "Neonatal/perinatal"
        case .nutrition: "Health nutrition"
        }
    }

    var examples: String {
        switch self {
        case .internalMedicine: "Chest pain, dyspnea, sepsis"
        case .surgery: "Abdominal pain, post-op fever"
        case .pediatrics: "Febrile infant, wheeze, rash"
        case .obgyn: "Bleeding in pregnancy, pelvic pain"
        case .psychiatry: "Low mood, psychosis, withdrawal"
        case .familyMedicine: "Cough, back pain, check-ups"
        case .neurology: "Headache, weakness, seizures"
        case .emergency: "Undifferentiated, time-critical"
        case .clinicalPsychology: "Intake, assessment, therapy plan"
        case .dermatology: "Rash, lesions, itch"
        case .allergyImmunology: "Anaphylaxis, hives, asthma"
        case .cardiology: "Chest pain, palpitations, heart failure"
        case .endocrinology: "Diabetes, thyroid, adrenal"
        case .geriatrics: "Delirium, falls, dementia"
        case .hematologyOncology: "Anemia, bleeding, cancers"
        case .infectiousDisease: "Fever, travel, STIs"
        case .nephrology: "Kidney injury, electrolytes"
        case .ophthalmology: "Red eye, vision loss"
        case .orthopedicSurgery: "Fractures, sprains, back pain"
        case .otolaryngology: "Ear pain, sinusitis, hoarseness"
        case .rehabilitation: "Stroke recovery, spinal injury"
        case .rheumatology: "Joint pain, lupus, gout"
        case .urology: "Kidney stones, prostate, blood in urine"
        case .neonatology: "Jaundice, breathing trouble, sepsis"
        case .nutrition: "Malnutrition, vitamin deficiencies"
        }
    }
}

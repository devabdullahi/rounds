import Foundation

// MARK: - Case content types

struct Vital: Identifiable {
    enum Tone { case accent, warn, info, plain }
    let id: String
    let label: String
    let value: String
    let tone: Tone
}

/// Something the patient tells you when you ask the right question.
struct HistoryFact: Identifiable {
    let id: String
    let label: String          // shown in the "Revealed" chip
    let keywords: [String]     // lower-case substrings matched against the question
    let reply: String
    var isRedFlagScreen = false
    var isKeyHistory = true    // counts toward history coverage
}

/// A one-tap prompt; hidden once its fact is revealed, however it was asked.
struct SuggestedQuestion: Hashable {
    let text: String
    let fact: String
}

struct ExamManeuver: Identifiable {
    let id: String
    let title: String
    let finding: String
    var isRedFlagScreen = false
}

struct Investigation: Identifiable {
    let id: String
    let name: String
    let detail: String
    let cost: Int
    let turnaround: Double     // seconds until result in-app
    let result: String
    var resultIsAbnormal = false
    var delaysCareMinutes = 0      // time added before definitive treatment
}

struct ClinicalCase {
    let bed: String
    let name: String
    let age: Int
    let initials: String
    let setting: String
    let quote: String
    let demeanor: String
    let complaint: String
    let vitals: [Vital]
    let task: String
    let minutes: Int
    let budget: Int
    let facts: [HistoryFact]
    let fallbackReply: String
    let suggestedQuestions: [SuggestedQuestion]
    let exam: [ExamManeuver]
    let tests: [Investigation]
    let acceptedDiagnoses: [String]   // lower-case substrings
    let canonicalDiagnosis: String
    let planKeywords: [String]
    let startingDifferential: [String]
}

// MARK: - Bed 4 · chest pain

extension ClinicalCase {
    static let chestPain = ClinicalCase(
        bed: "B4",
        name: "Mark Reyes",
        age: 54,
        initials: "MR",
        setting: "Walk-in, emergency department",
        quote: "My chest has been hurting since this morning.",
        demeanor: "Anxious and sweating",
        complaint: "Central chest pain that started about two hours ago while shoveling. Appears sweaty and anxious.",
        vitals: [
            Vital(id: "hr", label: "HR", value: "104", tone: .accent),
            Vital(id: "bp", label: "BP", value: "148/92", tone: .warn),
            Vital(id: "spo2", label: "SpO₂", value: "95%", tone: .info),
            Vital(id: "rr", label: "RR", value: "20", tone: .plain),
            Vital(id: "temp", label: "Temp", value: "36.9°", tone: .plain),
            Vital(id: "pain", label: "Pain", value: "7/10", tone: .plain),
        ],
        task: "Take a focused history, examine, order investigations, and give a working diagnosis with a plan.",
        minutes: 10,
        budget: 600,
        facts: [
            HistoryFact(id: "onset", label: "onset",
                        keywords: ["when", "start", "began", "onset", "how long", "doing"],
                        reply: "About two hours ago. I was out shoveling the driveway and it just came on."),
            HistoryFact(id: "site", label: "radiation, site",
                        keywords: ["where", "show me", "radiat", "spread", "go anywhere", "arm", "jaw", "move"],
                        reply: "Right here, in the middle. It kinda goes down my left arm too, and up into my jaw."),
            HistoryFact(id: "character", label: "character",
                        keywords: ["feel like", "describe", "kind of pain", "type of pain", "sharp", "crushing", "pressure", "dull", "what's it like", "what is it like"],
                        reply: "Heavy. Like an elephant sitting on me. Not sharp."),
            HistoryFact(id: "severity", label: "severity",
                        keywords: ["scale", "how bad", "severe", "out of 10", "out of ten", "score"],
                        reply: "Seven out of ten. Maybe eight. It hasn't let up.", isKeyHistory: false),
            HistoryFact(id: "associated", label: "associated symptoms",
                        keywords: ["sweat", "nause", "sick", "vomit", "breath", "dizz", "faint", "other symptoms", "anything else"],
                        reply: "I feel sick to my stomach and I'm sweating buckets. A bit short of breath."),
            HistoryFact(id: "risk", label: "smoking, family history",
                        keywords: ["smok", "cigarette", "family", "dad", "father", "mother", "heart problem", "heart disease"],
                        reply: "About a pack a day, yeah. My dad had a heart attack at 60."),
            HistoryFact(id: "pmh", label: "past history, meds",
                        keywords: ["medical history", "conditions", "blood pressure", "diabetes", "cholesterol", "medication", "meds", "pills", "take any", "past"],
                        reply: "High blood pressure. I'm meant to take amlodipine but I forget a lot. No diabetes that I know of."),
            HistoryFact(id: "previous", label: "previous episodes",
                        keywords: ["before", "previous", "happened", "first time", "ever had"],
                        reply: "Some tightness walking uphill this past month. It went away when I stopped. Never like this."),
            HistoryFact(id: "back", label: "no back pain (dissection)",
                        keywords: ["back", "tear", "rip", "between your shoulder", "shoulder blade"],
                        reply: "No, nothing in my back. It's not tearing, just heavy.", isRedFlagScreen: true, isKeyHistory: false),
            HistoryFact(id: "drugs", label: "no cocaine",
                        keywords: ["cocaine", "drugs", "recreational", "substance"],
                        reply: "No, nothing like that. Couple of beers on the weekend.", isRedFlagScreen: true, isKeyHistory: false),
            HistoryFact(id: "allergy", label: "allergies",
                        keywords: ["allerg"],
                        reply: "None that I know of.", isKeyHistory: false),
            HistoryFact(id: "pleuritic", label: "not pleuritic",
                        keywords: ["deep breath", "breathe in", "lean forward", "lying flat", "position", "press"],
                        reply: "Breathing doesn't change it. Doesn't matter how I sit either.", isKeyHistory: false),
        ],
        fallbackReply: "Sorry, doc, I'm not sure what you mean. It just really hurts.",
        suggestedQuestions: [
            SuggestedQuestion(text: "When did the pain start?", fact: "onset"),
            SuggestedQuestion(text: "Does the pain go anywhere?", fact: "site"),
            SuggestedQuestion(text: "What does it feel like?", fact: "character"),
            SuggestedQuestion(text: "Any sweating or nausea?", fact: "associated"),
            SuggestedQuestion(text: "Do you smoke?", fact: "risk"),
            SuggestedQuestion(text: "Any medical problems or meds?", fact: "pmh"),
            SuggestedQuestion(text: "Ever had this before?", fact: "previous"),
            SuggestedQuestion(text: "Any back pain?", fact: "back"),
            SuggestedQuestion(text: "Any recreational drugs?", fact: "drugs"),
        ],
        exam: [
            ExamManeuver(id: "inspect", title: "General inspection",
                         finding: "Pale, diaphoretic, clutching his chest. Speaking in full sentences."),
            ExamManeuver(id: "armbp", title: "Compare arm blood pressures",
                         finding: "Right 148/92, left 146/90. No significant difference.", isRedFlagScreen: true),
            ExamManeuver(id: "heart", title: "Auscultate heart",
                         finding: "Tachycardic, regular. Normal S1 and S2, no murmur or rub."),
            ExamManeuver(id: "lungs", title: "Auscultate lungs",
                         finding: "Clear bilaterally. No crackles."),
            ExamManeuver(id: "pulses", title: "Check peripheral pulses",
                         finding: "Radial and femoral pulses present and equal.", isRedFlagScreen: true),
            ExamManeuver(id: "legs", title: "Examine calves",
                         finding: "No swelling or tenderness. Wells score low."),
        ],
        tests: [
            Investigation(id: "ecg", name: "12-lead ECG", detail: "Bedside · 2 min", cost: 25, turnaround: 3,
                          result: "Sinus tachycardia 104. ST elevation in II, III, aVF with reciprocal depression in I, aVL.",
                          resultIsAbnormal: true),
            Investigation(id: "trop", name: "Troponin (hs)", detail: "Bloods · 3 min", cost: 45, turnaround: 6,
                          result: "312 ng/L (ref < 14). Markedly raised.", resultIsAbnormal: true),
            Investigation(id: "cxr", name: "Chest X-ray", detail: "Rules out dissection signs, pneumothorax", cost: 80, turnaround: 5,
                          result: "Normal mediastinal width. Clear lung fields. No pneumothorax."),
            Investigation(id: "fbc", name: "CBC, BMP", detail: "Bloods · 4 min", cost: 30, turnaround: 5,
                          result: "Hgb 14.2 g/dL, WBC 9.1, K⁺ 4.1, creatinine 1.0 mg/dL. Unremarkable."),
            Investigation(id: "ctpa", name: "CT pulmonary angiogram", detail: "Radiation · 25 min", cost: 900, turnaround: 8,
                          result: "No pulmonary embolism. Delayed reperfusion by 25 minutes.", delaysCareMinutes: 25),
        ],
        acceptedDiagnoses: ["stemi", "st elevation", "st-elevation", "myocardial infarction", "heart attack", "acs", "acute coronary"],
        canonicalDiagnosis: "Inferior STEMI",
        planKeywords: ["aspirin", "pci", "cath", "reperfusion", "thromboly", "cardiology"],
        startingDifferential: ["Aortic dissection", "Pulmonary embolism", "Pericarditis"]
    )
}

// MARK: - Ward board

/// A red flag or step skipped on a specific patient, with the reason it matters.
struct Miss: Identifiable, Hashable {
    var id: String { flag }
    let flag: String
    let why: String
}

struct WardPatient: Identifiable {
    let id: String
    let quote: String
    let meta: String
    let specialty: String
    let status: Status
    enum Status { case new, resume, revisit }
    var hasCase: Bool { id == "B4" }
}

enum Ward {
    static let specialties = ["All", "Cardiology", "Respiratory", "Abdominal", "Neuro"]

    static let rotation: [WardPatient] = [
        WardPatient(id: "B7", quote: "My heart keeps racing.", meta: "F · 31 · palpitations", specialty: "Cardiology", status: .new),
        WardPatient(id: "B8", quote: "My legs keep swelling.", meta: "F · 72 · edema", specialty: "Cardiology", status: .resume),
        WardPatient(id: "B9", quote: "I get breathless on stairs.", meta: "M · 67 · dyspnea", specialty: "Cardiology", status: .new),
        WardPatient(id: "R4", quote: "I can't stop wheezing.", meta: "M · 24 · wheeze", specialty: "Respiratory", status: .new),
        WardPatient(id: "A3", quote: "The pain moved to my right side.", meta: "F · 19 · abdominal pain", specialty: "Abdominal", status: .new),
        WardPatient(id: "N2", quote: "Worst headache of my life.", meta: "F · 45 · headache", specialty: "Neuro", status: .new),
    ]

    static let revisit: [WardPatient] = [
        WardPatient(id: "B4", quote: "My chest has been hurting.", meta: "M · 54 · chest pain", specialty: "Cardiology", status: .revisit),
        WardPatient(id: "R2", quote: "This cough won't go away.", meta: "M · 63 · chronic cough", specialty: "Respiratory", status: .revisit),
        WardPatient(id: "N1", quote: "My head is pounding.", meta: "F · 22 · headache", specialty: "Neuro", status: .revisit),
    ]

    /// Seed history: what was missed last time on each patient, and the score.
    static let seededMisses: [String: [Miss]] = [
        "R2": [
            Miss(flag: "Weight loss", why: "Cough plus weight loss in a smoker is lung cancer until proven otherwise."),
            Miss(flag: "Haemoptysis", why: "Coughing blood needs an urgent chest X-ray and 2-week-wait referral."),
        ],
        "N1": [
            Miss(flag: "Neck stiffness", why: "Fever with headache: check for meningism before calling it a migraine."),
            Miss(flag: "Non-blanching rash", why: "Petechiae mean meningococcal sepsis. Antibiotics before imaging."),
        ],
    ]
    static let seededScores: [String: Int] = ["R2": 61, "N1": 58]
}

/// Believable sample identity for the screens-only phase (replaces "[Your name]" brackets).
enum SampleUser {
    static let name = "Alex Kim"
    static let initials = "AK"
    static let training = "MS3, Riverside School of Medicine"
    static let email = "alex.kim@riverside.edu"
}

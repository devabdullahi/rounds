import Foundation

struct MockHealthTopics: HealthTopicLinking {
    /// Keyword in the diagnosis → page. First keyword found wins.
    private static let pages: [(keywords: [String], topic: HealthTopic)] = [
        (["stemi", "myocardial infarction", "heart attack", "acute coronary", "angina"],
         topic("Heart Attack", "What happens in a heart attack, warning signs, and treatment.", "heartattack")),
        (["pulmonary embolism"], topic("Pulmonary Embolism", "Blood clots in the lungs: causes, symptoms and treatment.", "pulmonaryembolism")),
        (["appendicitis"], topic("Appendicitis", "Inflammation of the appendix and why it's an emergency.", "appendicitis")),
        (["migraine"], topic("Migraine", "Migraine symptoms, triggers and treatment.", "migraine")),
        (["meningitis"], topic("Meningitis", "Infection of the membranes around the brain and spinal cord.", "meningitis")),
        (["reflux", "gerd"], topic("GERD", "Acid reflux, heartburn and how it's treated.", "gerd")),
        (["pneumonia"], topic("Pneumonia", "Lung infection: symptoms, causes and care.", "pneumonia")),
        (["asthma"], topic("Asthma", "Airway inflammation, attacks and long-term control.", "asthma")),
        (["atrial fibrillation", "afib"], topic("Atrial Fibrillation", "An irregular heartbeat and stroke prevention.", "atrialfibrillation")),
        (["heart failure"], topic("Heart Failure", "When the heart can't pump enough blood: symptoms and treatment.", "heartfailure")),
        (["panic"], topic("Panic Disorder", "Panic attacks and how they're treated.", "panicdisorder")),
    ]

    private static func topic(_ title: String, _ summary: String, _ slug: String) -> HealthTopic {
        HealthTopic(title: title, summary: summary, url: URL(string: "https://medlineplus.gov/\(slug).html")!)
    }

    func topics(for diagnosis: String) async throws -> [HealthTopic] {
        try await simulatedLatency()
        let d = ReferenceMatching.normalize(diagnosis)
        return Self.pages.first { $0.keywords.contains { d.contains($0) } }.map { [$0.topic] } ?? []
    }
}

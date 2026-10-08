import Foundation

/// Reads a request with keywords: the interpreter on phones without Apple Intelligence, and the
/// net under the on-device model when it can't answer. Topic words also brief that model.
enum CommandKeywords {
    /// Words students use for each topic. Longer phrases are tried first, so "family medicine"
    /// wins over "medicine". Two-letter abbreviations that are also everyday words ("im", "er")
    /// are left out.
    static let topics: [(focus: StudyFocus, words: [String])] = [
        (.rotation(.internalMedicine), ["internal medicine", "medicine"]),
        (.rotation(.surgery), ["surgery", "surgical"]),
        (.rotation(.pediatrics), ["pediatrics", "pediatric", "peds", "kids", "kid", "child", "children", "baby", "infant"]),
        (.rotation(.obgyn), ["ob gyn", "obgyn", "obstetrics", "gynecology", "pregnancy"]),
        (.rotation(.psychiatry), ["psychiatry", "psych"]),
        (.rotation(.familyMedicine), ["family medicine", "family med", "primary care"]),
        (.rotation(.neurology), ["neurology", "neuro"]),
        (.rotation(.emergency), ["emergency medicine", "emergency"]),
        (.rotation(.clinicalPsychology), ["clinical psychology", "psychology"]),
        (.rotation(.dermatology), ["dermatology", "derm", "skin"]),
        (.system(.cardiovascular), ["cardiovascular", "cardiology", "cardiac", "cardio", "heart"]),
        (.system(.respiratory), ["respiratory", "pulmonology", "pulmonary", "pulm", "lungs", "lung"]),
        (.system(.gastrointestinal), ["gastrointestinal", "gastroenterology", "gi", "gut"]),
        (.system(.renal), ["renal", "nephrology", "kidneys", "kidney"]),
        (.system(.nervous), ["nervous system", "nervous"]),
        (.system(.endocrine), ["endocrinology", "endocrine", "endo", "diabetes", "thyroid"]),
        (.system(.blood), ["hematology", "heme", "blood"]),
        (.system(.musculoskeletal), ["musculoskeletal", "orthopedics", "ortho", "msk", "bones"]),
        (.system(.reproductive), ["reproductive"]),
        (.system(.behavioral), ["behavioral"]),
    ]

    private static let numberWords = ["ten": 10, "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50]

    static func parse(_ request: String) -> RoundsCommand {
        let text = normalized(request)
        let words = Set(text.split(separator: " ").map(String.init))
        func has(_ any: String...) -> Bool { any.contains { $0.contains(" ") ? text.contains($0) : words.contains($0) } }

        let topic = topic(in: text)
        let count = count(in: text)
        if has("streak", "in a row") { return .streak }
        if has("mistake", "mistakes", "missed", "wrong", "errors", "messed up", "mess up") { return .reviewMistakes(count: count) }
        if has("card", "cards", "flashcard", "flashcards", "deck", "quiz", "drill") { return .makeCards(topic, count: count) }
        // A patient for later: queued on the ward, not opened now.
        if has("queue", "queued", "line up", "later", "tonight", "tomorrow", "after", "this evening") { return .queuePatient(topic) }
        if has("patient", "case", "admit", "start", "next", "sick") || topic != nil { return .startPatient(topic) }
        return .unclear
    }

    /// The topic a request names, if any.
    static func topic(in text: String) -> StudyFocus? {
        let padded = " \(normalized(text)) "
        let phrases = topics.flatMap { t in t.words.map { (word: $0, focus: t.focus) } }
            .sorted { $0.word.count > $1.word.count }
        return phrases.first { padded.contains(" \($0.word) ") }?.focus
    }

    /// A card count the request names, snapped to a size the server takes.
    static func count(in text: String) -> Int? {
        for word in normalized(text).split(separator: " ") {
            if let n = Int(word) ?? numberWords[String(word)], n > 0 { return RoundsCommand.snapCount(n) }
        }
        return nil
    }

    /// Lowercase words separated by single spaces ("OB/GYN" → "ob gyn").
    static func normalized(_ text: String) -> String {
        text.lowercased()
            .map { $0.isLetter || $0.isNumber ? $0 : " " }
            .reduce(into: "") { $0.append($1) }
            .split(separator: " ").joined(separator: " ")
    }
}

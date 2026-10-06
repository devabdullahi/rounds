import Foundation

/// Pure matching rules shared by the mocks (and later by caches over live results).
/// No I/O and no SwiftUI, so it's covered by unit tests.
enum ReferenceMatching {

    /// Ranks conditions against a partial query.
    /// Order: name starts with the query, then a synonym does, then a word inside the name or a
    /// synonym does, then the query appears anywhere. Ties keep catalog order. Case and accent blind.
    static func rankConditions(_ query: String, in catalog: [ConditionMatch], limit: Int) -> [ConditionMatch] {
        let q = normalize(query)
        guard q.count >= 2 else { return [] }

        func score(_ c: ConditionMatch) -> Int? {
            let name = normalize(c.name)
            let synonyms = c.synonyms.map(normalize)
            if name.hasPrefix(q) { return 0 }
            if synonyms.contains(where: { $0.hasPrefix(q) }) { return 1 }
            if ([name] + synonyms).contains(where: { words($0).contains { $0.hasPrefix(q) } }) { return 2 }
            if ([name] + synonyms).contains(where: { $0.contains(q) }) { return 3 }
            return nil
        }

        return catalog.enumerated()
            .compactMap { i, c in score(c).map { (rank: $0, index: i, match: c) } }
            .sorted { ($0.rank, $0.index) < ($1.rank, $1.index) }
            .prefix(limit)
            .map(\.match)
    }

    /// Finds drugs named in free text. Matches whole words only ("asa" in "ASA 325", not in "nasal"),
    /// each drug once, in order of first appearance.
    static func recognizeDrugs(in text: String, catalog: [(rxcui: String, name: String, aliases: [String])]) -> [DrugMatch] {
        let tokens = words(normalize(text))
        var found: [(position: Int, match: DrugMatch)] = []

        for drug in catalog {
            let spellings = ([drug.name] + drug.aliases).map(normalize)
            for spelling in spellings {
                let parts = words(spelling)
                guard let start = firstIndex(of: parts, in: tokens) else { continue }
                found.append((start, DrugMatch(rxcui: drug.rxcui, name: drug.name, matchedText: spelling)))
                break
            }
        }
        return found.sorted { $0.position < $1.position }.map(\.match)
    }

    /// Index-style names written the way a clinician says them: "Pneumonia - aspiration" →
    /// "Aspiration pneumonia". The head keeps its case when it starts with an acronym ("COPD").
    static func uninverted(_ name: String) -> String {
        let parts = name.components(separatedBy: " - ")
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return name }
        let head = parts[0], modifier = parts[1]
        let firstWord = head.prefix { $0 != " " }
        let keepCase = firstWord.count > 1 && firstWord == firstWord.uppercased()
        let headText = keepCase ? head : head.prefix(1).lowercased() + head.dropFirst()
        return modifier.prefix(1).uppercased() + modifier.dropFirst() + " " + headText
    }

    /// The synonym that explains a match the name doesn't ("PE" for "Pulmonary embolism"), so the
    /// student sees why it was suggested. Nil when the name itself matches.
    static func matchedSynonym(_ query: String, in match: ConditionMatch) -> String? {
        let q = normalize(query)
        guard q.count >= 2 else { return nil }
        func hits(_ text: String) -> Bool {
            let t = normalize(text)
            return t.hasPrefix(q) || words(t).contains { $0.hasPrefix(q) }
        }
        guard !hits(match.name) else { return nil }
        return match.synonyms.first(where: hits)
    }

    // MARK: Helpers

    static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .init(identifier: "en_US"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func words(_ s: String) -> [String] {
        s.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    /// Index where `needle` occurs as a run of consecutive tokens.
    private static func firstIndex(of needle: [String], in tokens: [String]) -> Int? {
        guard !needle.isEmpty, needle.count <= tokens.count else { return nil }
        return (0...(tokens.count - needle.count)).first { Array(tokens[$0..<$0 + needle.count]) == needle }
    }
}

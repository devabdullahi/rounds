import Foundation

/// Live diagnosis autocomplete from NLM Clinical Table Search: the conditions list (Regenstrief,
/// ~2,400 conditions with ICD-10-CM codes and synonyms). Free, no key. Results are cached for 12 h,
/// as NLM asks, so retyping a query never repeats a request.
struct ClinicalTablesConditionSearch: ConditionSearching {
    private let session: URLSession
    private let cache = ConditionSearchCache()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(_ text: String, limit: Int) async throws -> [ConditionMatch] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return [] }
        let key = "\(limit)|\(ReferenceMatching.normalize(query))"
        if let cached = await cache.value(for: key) { return cached }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "clinicaltables.nlm.nih.gov"
        components.path = "/api/conditions/v3/search"
        components.queryItems = [
            URLQueryItem(name: "terms", value: query),
            URLQueryItem(name: "maxList", value: String(Self.fetchCount)),
            URLQueryItem(name: "df", value: "primary_name,consumer_name"),
            URLQueryItem(name: "ef", value: "icd10cm_codes,synonyms"),
        ]
        guard let url = components.url else { throw URLError(.badURL) }

        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let matches = Self.rerank(try Self.matches(from: data, limit: Self.fetchCount), for: query, limit: limit)
        await cache.store(matches, for: key)
        return matches
    }

    /// The API ranks loosely ("pulm" puts upper respiratory infection above pulmonary embolism, and
    /// leaves the embolism out of a short list), so a wider page is fetched and re-ranked locally.
    private static let fetchCount = 20

    /// Our ranking first (name starts with the query, then a synonym does…), then whatever else the
    /// API matched (it also searches fields we don't receive), in its order.
    static func rerank(_ matches: [ConditionMatch], for query: String, limit: Int) -> [ConditionMatch] {
        let ranked = ReferenceMatching.rankConditions(query, in: matches, limit: matches.count)
        let rest = matches.filter { !ranked.contains($0) }
        return Array((ranked + rest).prefix(limit))
    }

    /// Maps the API's reply to domain matches, in the API's ranking order. Conditions without an
    /// ICD-10-CM code are skipped (a match is identified by its code), and so are repeats of a code.
    static func matches(from data: Data, limit: Int) throws -> [ConditionMatch] {
        let reply = try JSONDecoder().decode(ConditionSearchReply.self, from: data)
        var seen = Set<String>()
        var out: [ConditionMatch] = []
        for (i, names) in reply.display.enumerated() {
            let codes = reply.extras.icd10cmCodes?[safe: i].flatMap { $0 } ?? ""
            guard let code = codes.split(separator: ",").first.map({ $0.trimmingCharacters(in: .whitespaces) }),
                  !code.isEmpty, seen.insert(code).inserted,
                  let name = names.first else { continue }
            let listed = names.dropFirst() + (reply.extras.synonyms?[safe: i].flatMap { $0 } ?? [])
            var synonyms: [String] = []
            for s in listed where s.caseInsensitiveCompare(name) != .orderedSame && !synonyms.contains(s) {
                synonyms.append(s)
            }
            out.append(ConditionMatch(code: code, name: name, synonyms: synonyms))
            if out.count == limit { break }
        }
        return out
    }
}

/// Wire format: `[total, [keys], {extra fields}, [[display fields]]]`. Only this file sees it.
private struct ConditionSearchReply: Decodable {
    struct Extras: Decodable {
        /// One comma-separated string per result ("T76.92XA, T76.92XD"), or null.
        var icd10cmCodes: [String?]?
        var synonyms: [[String]?]?

        enum CodingKeys: String, CodingKey {
            case icd10cmCodes = "icd10cm_codes"
            case synonyms
        }
    }

    let extras: Extras
    let display: [[String]]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        _ = try container.decode(Int.self)
        _ = try container.decode([String].self)
        extras = try container.decodeIfPresent(Extras.self) ?? Extras()
        display = try container.decode([[String]].self)
    }
}

/// Recent answers by query, kept 12 hours and capped so a long session can't grow it unbounded.
private actor ConditionSearchCache {
    private static let lifetime: TimeInterval = 12 * 60 * 60
    private static let capacity = 300
    private var entries: [String: (matches: [ConditionMatch], stored: Date)] = [:]

    func value(for key: String) -> [ConditionMatch]? {
        guard let entry = entries[key], Date().timeIntervalSince(entry.stored) < Self.lifetime else { return nil }
        return entry.matches
    }

    func store(_ matches: [ConditionMatch], for key: String) {
        if entries.count >= Self.capacity, let oldest = entries.min(by: { $0.value.stored < $1.value.stored })?.key {
            entries[oldest] = nil
        }
        entries[key] = (matches, Date())
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

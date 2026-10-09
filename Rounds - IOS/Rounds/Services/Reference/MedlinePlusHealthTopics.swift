import Foundation

/// Live "Learn more" pages from MedlinePlus (NLM's health-topic search: wsearch.nlm.nih.gov, free,
/// no key). Searches by the diagnosis name and returns the best-ranked topic pages with a one-line
/// summary. Results are cached for 24 h, within NLM's guidance, so a revisited debrief never
/// repeats a request.
struct MedlinePlusHealthTopics: HealthTopicLinking {
    /// Pages shown per diagnosis: the best match, plus one alternative when the name is ambiguous.
    static let pageCount = 2
    /// Summary length for a debrief row.
    static let summaryLength = 140

    private let session: URLSession
    private let cache = HealthTopicCache()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func topics(for diagnosis: String) async throws -> [HealthTopic] {
        let term = diagnosis.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.count >= 3 else { return [] }
        let key = ReferenceMatching.normalize(term)
        if let cached = await cache.value(for: key) { return cached }

        // MedlinePlus uses patient names, so a precise clinical name ("hypertrophic pyloric stenosis")
        // can match nothing. Leading qualifiers are dropped until something matches.
        var topics: [HealthTopic] = []
        for query in Self.queries(for: term) {
            topics = try await search(query)
            if !topics.isEmpty { break }
        }
        await cache.store(topics, for: key)
        return topics
    }

    /// The name, then without its leading qualifier words, down to the last two words
    /// ("recurrent aphthous stomatitis" → "aphthous stomatitis").
    static func queries(for term: String) -> [String] {
        let words = term.split(separator: " ")
        guard words.count > 2 else { return [term] }
        return (0...(words.count - 2)).prefix(3).map { words[$0...].joined(separator: " ") }
    }

    private func search(_ term: String) async throws -> [HealthTopic] {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "wsearch.nlm.nih.gov"
        components.path = "/ws/query"
        components.queryItems = [
            URLQueryItem(name: "db", value: "healthTopics"),
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "retmax", value: String(Self.pageCount)),
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return Self.topics(from: data)
    }

    /// Maps the search reply (XML) to topics, in MedlinePlus's ranking order. Titles and summaries
    /// arrive with search-highlight HTML, which is stripped; a summary is cut at a sentence end.
    static func topics(from data: Data) -> [HealthTopic] {
        let reader = SearchReplyReader()
        let parser = XMLParser(data: data)
        parser.delegate = reader
        parser.parse()
        return reader.documents.compactMap { doc in
            guard let url = URL(string: doc.url), let title = doc.title.map(plainText), !title.isEmpty else { return nil }
            return HealthTopic(title: title, summary: doc.summary.map { shortSummary(plainText($0)) } ?? "", url: url)
        }
    }

    /// Text without tags or entities, with whitespace collapsed.
    static func plainText(_ html: String) -> String {
        var text = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        for (entity, char) in [("&amp;", "&"), ("&quot;", "\""), ("&#39;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " ")] {
            text = text.replacingOccurrences(of: entity, with: char)
        }
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The summary's first sentences that fit in a row. MedlinePlus summaries often open with a
    /// question heading ("What is a heart attack?"), which is skipped.
    static func shortSummary(_ text: String) -> String {
        var sentences = text.components(separatedBy: ". ").map { $0.trimmingCharacters(in: .whitespaces) }
        if let first = sentences.first, let mark = first.firstIndex(of: "?") {
            sentences[0] = String(first[first.index(after: mark)...]).trimmingCharacters(in: .whitespaces)
        }
        var out = ""
        for sentence in sentences where !sentence.isEmpty {
            let next = out.isEmpty ? sentence : out + ". " + sentence
            if next.count > summaryLength { break }
            out = next
        }
        if out.isEmpty, let first = sentences.first(where: { !$0.isEmpty }) { out = String(first.prefix(summaryLength)) }
        return out.hasSuffix(".") || out.isEmpty ? out : out + "."
    }
}

/// Pulls each `<document url=…>` with its title and FullSummary out of the search reply.
private final class SearchReplyReader: NSObject, XMLParserDelegate {
    struct Document { var url: String; var title: String?; var summary: String? }
    private(set) var documents: [Document] = []
    private var field: String?
    private var buffer = ""

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        if name == "document", let url = attributes["url"] {
            documents.append(Document(url: url))
        } else if name == "content", let kind = attributes["name"], kind == "title" || kind == "FullSummary" {
            field = kind
            buffer = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if field != nil { buffer += string }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        guard name == "content", let kind = field, !documents.isEmpty else { return }
        if kind == "title", documents[documents.count - 1].title == nil { documents[documents.count - 1].title = buffer }
        if kind == "FullSummary", documents[documents.count - 1].summary == nil { documents[documents.count - 1].summary = buffer }
        field = nil
    }
}

/// Topics per normalized diagnosis, kept 24 h.
private actor HealthTopicCache {
    private static let lifetime: TimeInterval = 24 * 60 * 60
    private var entries: [String: (topics: [HealthTopic], stored: Date)] = [:]

    func value(for key: String) -> [HealthTopic]? {
        guard let entry = entries[key], Date().timeIntervalSince(entry.stored) < Self.lifetime else { return nil }
        return entry.topics
    }

    func store(_ topics: [HealthTopic], for key: String) {
        entries[key] = (topics, Date())
    }
}

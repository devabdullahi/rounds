import Foundation

/// Live drug recognition from NLM RxNorm (RxNav REST: rxnav.nlm.nih.gov, free, no key).
///
/// RxNav has no "find drugs in this sentence" call, so recognition is local against RxNorm's own
/// list of drug names (`displaynames`, about 28,000 generic and brand names, downloaded once and
/// kept on disk for a week). Each name found is then resolved to its RxNorm concept id with one
/// `rxcui` lookup, cached for the session. Clinical shorthand RxNorm doesn't list (ASA, NTG, tPA)
/// is translated to the drug's name first, then resolved the same way, so every id is RxNorm's.
struct RxNormDrugRecognizer: DrugRecognizing {
    private let session: URLSession
    private let store: RxNormStore

    init(session: URLSession = .shared) {
        self.session = session
        self.store = RxNormStore(session: session)
    }

    func recognize(in text: String) async throws -> [DrugMatch] {
        let names = try await store.names()
        var out: [DrugMatch] = []
        for found in Self.find(in: text, names: names) where !out.contains(where: { $0.name == found.name }) {
            guard let rxcui = try await store.rxcui(for: found.name) else { continue }
            out.append(DrugMatch(rxcui: rxcui, name: Self.display(found.name), matchedText: found.typed))
        }
        return out
    }

    /// Shorthand clinicians write in plans that RxNorm doesn't list, mapped to the RxNorm name.
    static let shorthand: [String: String] = [
        "asa": "aspirin", "apap": "acetaminophen", "ntg": "nitroglycerin", "nitro": "nitroglycerin",
        "tpa": "alteplase", "o2": "oxygen", "ns": "sodium chloride", "normal saline": "sodium chloride",
        "lr": "lactated ringer's", "lactated ringers": "lactated ringer's", "d5w": "dextrose",
        "ufh": "heparin", "lmwh": "enoxaparin", "abx": "", "ppi": "",
    ].filter { !$0.value.isEmpty }

    /// Single words in RxNorm's list that are plain English in a plan, not a drug order.
    static let ignored: Set<String> = ["water", "air", "ice", "rest", "silver", "gold", "sugar", "salt", "milk", "honey"]

    /// Drug names in the text, in reading order: the longest RxNorm name (up to four words)
    /// starting at each word wins, so "sodium chloride" beats "sodium".
    static func find(in text: String, names: Set<String>) -> [(name: String, typed: String)] {
        let tokens = ReferenceMatching.words(ReferenceMatching.normalize(text))
        var out: [(String, String)] = []
        var i = 0
        while i < tokens.count {
            var matched = false
            for length in stride(from: min(4, tokens.count - i), through: 1, by: -1) {
                let phrase = tokens[i..<(i + length)].joined(separator: " ")
                if let name = shorthand[phrase] {
                    out.append((name, phrase)); i += length; matched = true; break
                }
                guard names.contains(phrase), !(length == 1 && (phrase.count < 4 || ignored.contains(phrase))) else { continue }
                out.append((phrase, phrase)); i += length; matched = true; break
            }
            if !matched { i += 1 }
        }
        return out
    }

    /// "metoprolol" → "Metoprolol"; brand names keep RxNorm's case where it has capitals.
    static func display(_ name: String) -> String {
        name.prefix(1).uppercased() + name.dropFirst()
    }
}

/// RxNorm's name list (memory, then disk, then network) and name → rxcui answers.
private actor RxNormStore {
    private static let lifetime: TimeInterval = 7 * 24 * 60 * 60
    private static let fileName = "rxnorm-displaynames.json"

    private let session: URLSession
    private var cachedNames: Set<String>?
    private var loading: Task<Set<String>, Error>?
    private var rxcuis: [String: String?] = [:]

    init(session: URLSession) {
        self.session = session
    }

    func names() async throws -> Set<String> {
        if let cachedNames { return cachedNames }
        if let loading { return try await loading.value }
        let task = Task { try await Self.loadNames(session: session) }
        loading = task
        defer { loading = nil }
        let names = try await task.value
        cachedNames = names
        return names
    }

    func rxcui(for name: String) async throws -> String? {
        if let known = rxcuis[name] { return known }
        var components = URLComponents(string: "https://rxnav.nlm.nih.gov/REST/rxcui.json")
        components?.queryItems = [URLQueryItem(name: "name", value: name), URLQueryItem(name: "search", value: "2")]
        guard let url = components?.url else { throw URLError(.badURL) }
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let id = try JSONDecoder().decode(RxcuiReply.self, from: data).idGroup.rxnormId?.first
        rxcuis[name] = id
        return id
    }

    private static func loadNames(session: URLSession) async throws -> Set<String> {
        let file = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName)
        if let file, let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
           let modified = attributes[.modificationDate] as? Date, Date().timeIntervalSince(modified) < lifetime,
           let data = try? Data(contentsOf: file), let names = try? parse(data) {
            return names
        }
        guard let url = URL(string: "https://rxnav.nlm.nih.gov/REST/displaynames.json") else { throw URLError(.badURL) }
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let names = try parse(data)
        if let file { try? data.write(to: file, options: .atomic) }
        return names
    }

    /// Lowercased names of at most four words, without the pack and kit entries.
    private static func parse(_ data: Data) throws -> Set<String> {
        let terms = try JSONDecoder().decode(DisplayNamesReply.self, from: data).displayTermsList.term
        return Set(terms.lazy.map { $0.lowercased() }.filter { name in
            name.split(separator: " ").count <= 4 && !name.contains("kit") && !name.contains("pack") && name.rangeOfCharacter(from: .decimalDigits) == nil
        })
    }
}

private struct DisplayNamesReply: Decodable {
    struct List: Decodable { let term: [String] }
    let displayTermsList: List
}

private struct RxcuiReply: Decodable {
    struct Group: Decodable { let rxnormId: [String]? }
    let idGroup: Group
}

import Foundation
import Supabase

/// Flashcard storage and generation. Models depend on the protocol; `LiveCardService` is Supabase.
protocol CardService: Sendable {
    /// Built-in decks plus the student's own cards, oldest first.
    func cards() async throws -> [Flashcard]
    /// Saves a hand-written card and returns it with its row id.
    func add(_ card: Flashcard) async throws -> Flashcard
    /// Writes a deck from condition profiles for the topics (`StudyFocus.stored` values).
    func generate(topics: [String], count: Int, includeMisses: Bool, deck: String) async throws -> [Flashcard]
    /// Deletes every card the student wrote or generated. Built-in decks stay.
    func clearMine() async throws
}

struct LiveCardService: CardService {
    let client: SupabaseClient

    private func userID() async throws -> UUID {
        if let session = try? await client.auth.session { return session.user.id }
        return try await client.auth.signInAnonymously().user.id
    }

    func cards() async throws -> [Flashcard] {
        let me = try await userID()
        let rows: [CardRow] = try await client.from("flashcards")
            .select("id, user_id, deck, topic, front, back, color, source")
            .order("created_at", ascending: true)
            .execute().value
        return rows.map { $0.flashcard(me: me) }
    }

    func add(_ card: Flashcard) async throws -> Flashcard {
        let me = try await userID()
        let row: CardRow = try await client.from("flashcards")
            .insert(NewCardRow(user_id: me, deck: card.deck, topic: card.topic, front: card.front, back: card.back, color: card.color.rawValue))
            .select("id, user_id, deck, topic, front, back, color, source")
            .single()
            .execute().value
        return row.flashcard(me: me)
    }

    func generate(topics: [String], count: Int, includeMisses: Bool, deck: String) async throws -> [Flashcard] {
        let me = try await userID()
        do {
            let reply: GenerateReply = try await client.functions.invoke(
                "generate-cards",
                options: FunctionInvokeOptions(body: GenerateBody(topics: topics, count: count, include_misses: includeMisses, deck: deck)))
            return reply.cards.map { CardRow(id: $0.id, user_id: me, deck: reply.deck, topic: $0.topic, front: $0.front,
                                             back: $0.back, color: $0.color, source: $0.source).flashcard(me: me) }
        } catch let FunctionsError.httpError(code, data) {
            let message = (try? JSONDecoder().decode(ErrorReply.self, from: data))?.error
            throw CaseServiceError(message: message.map { "\($0.prefix(1).uppercased())\($0.dropFirst())." } ?? "The server returned \(code).")
        }
    }

    func clearMine() async throws {
        let me = try await userID()
        try await client.from("flashcards").delete().eq("user_id", value: me).execute()
    }
}

// MARK: - Wire types

private struct CardRow: Decodable {
    let id: String
    let user_id: UUID?
    let deck: String
    let topic: String
    let front: String
    let back: String
    let color: String
    let source: String?

    func flashcard(me: UUID) -> Flashcard {
        Flashcard(serverID: id, deck: deck, topic: topic, front: front, back: back,
                  color: CardColor(rawValue: color) ?? .standard, source: source, isMine: user_id == me)
    }
}

private struct NewCardRow: Encodable {
    let user_id: UUID
    let deck: String
    let topic: String
    let front: String
    let back: String
    let color: String
}

private struct GenerateBody: Encodable {
    let topics: [String]
    let count: Int
    let include_misses: Bool
    let deck: String
}

private struct GenerateReply: Decodable {
    struct Card: Decodable { let id: String; let topic: String; let front: String; let back: String; let source: String?; let color: String }
    let deck: String
    let cards: [Card]
}

private struct ErrorReply: Decodable { let error: String }

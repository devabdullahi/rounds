import Foundation
import Supabase

/// `AccountSubscriptionService` over the `subscription` edge function.
struct LiveAccountSubscriptionService: AccountSubscriptionService {
    let client: SupabaseClient

    func claim(transactionID: String) async throws -> AccountAccess {
        let reply: AccessReply = try await client.invokeSigned("subscription", body: ClaimBody(transaction_id: transactionID))
        return reply.access
    }

    func status() async throws -> AccountAccess {
        let reply: AccessReply = try await client.invokeSigned("subscription", body: ["action": "status"])
        return reply.access
    }
}

private struct ClaimBody: Encodable {
    let action = "claim"
    let transaction_id: String
}

private struct AccessReply: Decodable {
    let entitled: Bool
    let owner: String?
    var access: AccountAccess { AccountAccess(entitled: entitled, ownedBy: owner) }
}

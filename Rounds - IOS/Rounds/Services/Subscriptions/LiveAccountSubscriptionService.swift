import Foundation
import Supabase

/// `AccountSubscriptionService` over the `subscription` edge function.
struct LiveAccountSubscriptionService: AccountSubscriptionService {
    let client: SupabaseClient

    func claim(transactionID: String) async throws -> AccountAccess {
        let reply: AccessReply = try await client.invokeSigned("subscription", body: PurchaseBody(action: "claim", transaction_id: transactionID))
        return reply.access
    }

    func transfer(transactionID: String) async throws -> AccountAccess {
        let reply: AccessReply = try await client.invokeSigned("subscription", body: PurchaseBody(action: "transfer", transaction_id: transactionID))
        return reply.access
    }

    func status() async throws -> AccountAccess {
        let reply: AccessReply = try await client.invokeSigned("subscription", body: ["action": "status"])
        return reply.access
    }
}

private struct PurchaseBody: Encodable {
    let action: String
    let transaction_id: String
}

private struct AccessReply: Decodable {
    let entitled: Bool
    let owner: String?
    /// Only `status` sends it; older servers never do.
    let free_case: Bool?
    var access: AccountAccess { AccountAccess(entitled: entitled, ownedBy: owner, freeCase: free_case ?? false) }
}

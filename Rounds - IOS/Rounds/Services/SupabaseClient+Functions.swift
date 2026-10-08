import Foundation
import Supabase

extension SupabaseClient {
    /// Calls an edge function with a fresh access token. `auth.session` refreshes an expired token,
    /// but the functions client only learns the new one from a later auth event, so a call right after
    /// launch (or from Siri, with the app cold in the background) could send the stale one and get
    /// 401 "invalid token". Passing the header ourselves removes the race.
    func invokeSigned<Reply: Decodable>(_ function: String, body: some Encodable) async throws -> Reply {
        try await functions.invoke(function, options: FunctionInvokeOptions(headers: try await bearer(), body: body))
    }

    /// The same, for functions that take no body.
    func invokeSigned<Reply: Decodable>(_ function: String) async throws -> Reply {
        try await functions.invoke(function, options: FunctionInvokeOptions(headers: try await bearer()))
    }

    private func bearer() async throws -> [String: String] {
        ["Authorization": "Bearer \(try await auth.session.accessToken)"]
    }
}

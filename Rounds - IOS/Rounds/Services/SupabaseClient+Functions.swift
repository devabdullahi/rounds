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

    /// Calls an edge function and hands back its response body as it arrives, for replies that are
    /// a stream (the patient's voice). The functions client buffers whole responses, so this goes
    /// through URLSession with the same fresh token.
    func streamSigned(_ function: String, body: some Encodable, project: (url: URL, key: String)) async throws -> URLSession.AsyncBytes {
        var request = URLRequest(url: project.url.appending(path: "functions/v1/\(function)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(project.key, forHTTPHeaderField: "apikey")
        for (field, value) in try await bearer() { request.setValue(value, forHTTPHeaderField: field) }
        request.httpBody = try JSONEncoder().encode(body)
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            var data = Data()
            for try await byte in bytes { data.append(byte) }
            throw FunctionsError.httpError(code: status, data: data)
        }
        return bytes
    }

    private func bearer() async throws -> [String: String] {
        ["Authorization": "Bearer \(try await auth.session.accessToken)"]
    }
}

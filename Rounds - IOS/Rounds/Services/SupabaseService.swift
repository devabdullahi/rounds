import Foundation
import Supabase

/// Supabase connection used by `LiveCaseService`.
///
/// Values come from Config/Secrets.xcconfig (git-ignored) via Info.plist. While they're empty,
/// `client` is nil and nothing tries to connect.
enum SupabaseService {
    /// The project URL and anon key, or nil while Secrets.xcconfig is empty.
    static let project: (url: URL, key: String)? = {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
            !urlString.isEmpty, !key.isEmpty,
            let url = URL(string: urlString)
        else { return nil }
        return (url, key)
    }()

    /// Every request to the project, the SDK's and the voice stream's. Edge functions that call an
    /// AI model can run up to 90s (the model's own timeout), past URLSession's default 60s, so a
    /// student would see a failure while the server still finished the work. 100s covers the
    /// slowest call; the resource limit bounds a whole streamed reply.
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 100
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }()

    static let client: SupabaseClient? = {
        guard let (url, key) = project else { return nil }
        // Opt in to the SDK's next-major behaviour (supabase-swift#822): the stored session is
        // emitted as the initial session as-is, even if expired. Nothing here listens to auth
        // events; every call goes through `auth.session`, which refreshes an expired session.
        return SupabaseClient(supabaseURL: url, supabaseKey: key,
                              options: SupabaseClientOptions(auth: .init(emitLocalSessionAsInitialSession: true),
                                                             global: .init(session: session)))
    }()

    static var isConfigured: Bool { client != nil }
}

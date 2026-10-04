import Foundation
import Supabase

/// Supabase connection. Set up but not used by any screen yet: the app still runs on sample data.
///
/// Values come from Config/Secrets.xcconfig (git-ignored) via Info.plist. While they're empty,
/// `client` is nil and nothing tries to connect.
enum SupabaseService {
    static let client: SupabaseClient? = {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
            !urlString.isEmpty, !key.isEmpty,
            let url = URL(string: urlString)
        else { return nil }
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }()

    static var isConfigured: Bool { client != nil }
}

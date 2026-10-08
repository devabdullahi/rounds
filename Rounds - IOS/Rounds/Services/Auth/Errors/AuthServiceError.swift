import Foundation
import Supabase

/// An account action failed for a reason the student can act on; the message is shown as is.
struct AuthServiceError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

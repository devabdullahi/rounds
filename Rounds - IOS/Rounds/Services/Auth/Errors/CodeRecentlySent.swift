import Foundation
import Supabase

/// A code went to this address moments ago, so the server won't send another yet. Not a failure
/// for the student: the code in their inbox still works, so they go on to enter it.
struct CodeRecentlySent: Error {
    /// Seconds until another code may be sent.
    let wait: TimeInterval
}

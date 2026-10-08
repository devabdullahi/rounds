import Foundation
import Supabase

/// The emailed code was wrong or expired: the code screen shows this inline, not as an alert.
struct CodeRejected: Error {}

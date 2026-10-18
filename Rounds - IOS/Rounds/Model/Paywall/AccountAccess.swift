import Foundation

/// The server's answer on whether the signed-in Rounds account has paid. Subscriptions belong to the
/// account that bought them, so a phone's Apple ID paying isn't enough on its own.
struct AccountAccess: Equatable, Sendable {
    let entitled: Bool
    /// When the phone's subscription belongs to a different account: who, masked ("j•••@gmail.com").
    var ownedBy: String? = nil
}

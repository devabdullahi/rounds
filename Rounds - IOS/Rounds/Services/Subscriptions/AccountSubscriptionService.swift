import Foundation

/// Ties App Store purchases to the Rounds account. Live: the `subscription` edge function, which asks
/// Apple about each purchase; tests and previews: `MockAccountSubscriptionService`.
protocol AccountSubscriptionService: Sendable {
    /// Hands a purchase on this phone to the signed-in account. A plan another account is using
    /// stays theirs: this one gets `entitled` false and who has it. A lapsed plan is free to take.
    func claim(transactionID: String) async throws -> AccountAccess
    /// Moves the phone's plan to the signed-in account, at the student's request; the account that
    /// had it loses access. `signedTransaction` (the phone's StoreKit JWS) proves the phone holds it.
    func transfer(transactionID: String, signedTransaction: String) async throws -> AccountAccess
    /// Whether the signed-in account has an active subscription, on any device.
    func status() async throws -> AccountAccess
}

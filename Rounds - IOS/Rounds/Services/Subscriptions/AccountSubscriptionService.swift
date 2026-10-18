import Foundation

/// Ties App Store purchases to the Rounds account. Live: the `subscription` edge function, which asks
/// Apple about each purchase; tests and previews: `MockAccountSubscriptionService`.
protocol AccountSubscriptionService: Sendable {
    /// Hands a purchase on this phone to the signed-in account. The first account to claim a
    /// subscription owns it; another account gets `entitled` false and who owns it.
    func claim(transactionID: String) async throws -> AccountAccess
    /// Whether the signed-in account has an active subscription, on any device.
    func status() async throws -> AccountAccess
}

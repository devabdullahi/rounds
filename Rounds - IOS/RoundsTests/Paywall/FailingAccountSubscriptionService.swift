import Foundation
@testable import Rounds

/// A subscription server that can't be reached: every call throws.
struct FailingAccountSubscriptionService: AccountSubscriptionService {
    struct Unreachable: Error {}
    func claim(transactionID: String) async throws -> AccountAccess { throw Unreachable() }
    func transfer(transactionID: String) async throws -> AccountAccess { throw Unreachable() }
    func status() async throws -> AccountAccess { throw Unreachable() }
}

import Foundation

/// A scripted subscription server for tests and previews: what a claim and a status check answer.
actor MockAccountSubscriptionService: AccountSubscriptionService {
    private let claimAnswer: AccountAccess
    private var statusAnswer: AccountAccess
    private(set) var claimed: [String] = []
    private(set) var transferred: [String] = []

    init(claim: AccountAccess = AccountAccess(entitled: true), status: AccountAccess = AccountAccess(entitled: false)) {
        claimAnswer = claim
        statusAnswer = status
    }

    func claim(transactionID: String) async throws -> AccountAccess {
        claimed.append(transactionID)
        return claimAnswer
    }

    func transfer(transactionID: String) async throws -> AccountAccess {
        transferred.append(transactionID)
        return AccountAccess(entitled: true)
    }

    func status() async throws -> AccountAccess { statusAnswer }

    /// What later status checks answer (a free case used up, a plan bought elsewhere).
    func answerStatus(_ access: AccountAccess) { statusAnswer = access }
}

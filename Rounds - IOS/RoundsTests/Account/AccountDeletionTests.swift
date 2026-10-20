import Testing
@testable import Rounds

struct AccountDeletionTests {
    /// Apple keeps billing a deleted account's subscription, so the confirmation must say so.
    @Test func confirmationSaysDeletingDoesNotCancelTheSubscription() {
        #expect(AccountDeletion.message.contains("doesn't cancel your subscription"))
        #expect(AccountDeletion.manage == "Manage subscription")
    }
}

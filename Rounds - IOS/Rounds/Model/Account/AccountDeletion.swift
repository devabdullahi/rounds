import Foundation

/// What the delete-account confirmation says, shared by Settings and the paywall. A subscription
/// lives on the student's Apple ID, so only they can cancel it: deleting the account doesn't, and
/// Apple keeps billing. (A plan kept that way is claimed by their next account on the same Apple ID.)
enum AccountDeletion {
    static let title = "Delete your account?"
    static let message = "Your patients, grades, flashcards and badges are deleted for good. This can't be undone.\n\n"
        + "Deleting your account doesn't cancel your subscription. Apple keeps billing you until you cancel it in your subscription settings."
    static let confirm = "Delete account and data"
    static let manage = "Manage subscription"
}

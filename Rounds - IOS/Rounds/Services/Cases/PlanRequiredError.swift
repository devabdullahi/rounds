import Foundation

/// The server refused because the account has no plan (HTTP 402): its free cases are used up, or it
/// asked for something the free cases don't include, like a generated deck.
/// Kept apart from `CaseServiceError` so the app can offer plans instead of showing an error.
struct PlanRequiredError: LocalizedError {
    var errorDescription: String? { "Your free patients are used up. Choose a plan to keep going." }
}

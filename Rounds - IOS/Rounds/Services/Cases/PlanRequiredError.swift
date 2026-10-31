import Foundation

/// The server refused because the account has no plan and its free cases are used up (HTTP 402).
/// Kept apart from `CaseServiceError` so the app can offer plans instead of showing an error.
struct PlanRequiredError: LocalizedError {
    var errorDescription: String? { "Your free patients are used up. Choose a plan to keep going." }
}

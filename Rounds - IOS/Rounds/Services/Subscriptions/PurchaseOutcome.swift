import Foundation

/// How a purchase attempt ended.
enum PurchaseOutcome: Sendable, Equatable {
    case purchased
    /// The student closed Apple's sheet.
    case cancelled
    /// Waiting on someone else, e.g. Ask to Buy; access arrives through entitlement updates.
    case pending
}

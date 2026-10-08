import Foundation

/// A backend failure, phrased for the student.
struct CaseServiceError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

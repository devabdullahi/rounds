import Foundation

/// Email addresses as typed into the sign-in forms: one normal form for keys and requests, and a
/// light shape check before sending a code (the server is the real judge of an address).
enum EmailAddress {
    /// Trimmed and lowercased, so "Sam@School.edu " and "sam@school.edu" are the same student.
    static func normalized(_ typed: String) -> String {
        typed.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func looksValid(_ typed: String) -> Bool {
        let address = normalized(typed)
        let parts = address.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty,
              address.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return false }
        let domain = parts[1]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".") && !domain.contains("..")
    }
}

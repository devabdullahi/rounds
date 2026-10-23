import Foundation

/// How the welcome badge names a student: "Dr." and their last name, the way they'll be called on
/// the wards. One-word names use that word; no name gives nil, and the badge says "Student doctor".
enum DoctorTitle {
    static func from(fullName: String?) -> String? {
        let words = (fullName ?? "").split(whereSeparator: \.isWhitespace)
        guard let last = words.last else { return nil }
        return "Dr. \(last)"
    }

    /// The first name, for "Welcome to the team, Sam".
    static func firstName(of fullName: String?) -> String? {
        (fullName ?? "").split(whereSeparator: \.isWhitespace).first.map(String.init)
    }
}

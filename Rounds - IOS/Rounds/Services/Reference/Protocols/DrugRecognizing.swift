import Foundation

protocol DrugRecognizing: Sendable {
    /// Drugs mentioned anywhere in free text, in the order they appear.
    func recognize(in text: String) async throws -> [DrugMatch]
}

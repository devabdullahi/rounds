import Foundation

protocol DiseaseFactProviding: Sendable {
    func facts(forCode code: String) async throws -> DiseaseFacts?
}

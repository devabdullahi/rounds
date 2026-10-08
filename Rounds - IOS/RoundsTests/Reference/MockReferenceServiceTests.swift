import Testing
@testable import Rounds

@Suite("Mock reference services")
struct MockReferenceServiceTests {
    @Test func debriefFindsReadingForTheCaseDiagnosis() async throws {
        let topics = try await MockHealthTopics().topics(for: "Inferior STEMI")
        #expect(topics.map(\.title) == ["Heart Attack"])
        #expect(topics.first?.url.host() == "medlineplus.gov")
    }

    @Test func unknownDiagnosisHasNoReading() async throws {
        #expect(try await MockHealthTopics().topics(for: "Something rare").isEmpty)
    }

    @Test func authoringHelpersAnswerForTheChestPainCase() async throws {
        let facts = try await MockDiseaseFacts().facts(forCode: "I21.19")
        #expect(facts?.redFlags.isEmpty == false)
        let patient = try await MockSyntheticPatients().patient(forCode: "I21.19")
        #expect(patient.age == 54)
        let ddx = try await MockDifferentialChecker().differential(for: ["chest pain", "sweating"])
        #expect(ddx.first?.name == "STEMI")
    }
}

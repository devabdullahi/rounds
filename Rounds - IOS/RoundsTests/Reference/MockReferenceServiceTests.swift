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
}

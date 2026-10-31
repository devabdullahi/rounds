import Foundation
import Testing
@testable import Rounds

/// Admitting when the focus's first condition is still being written: the app asks again until a
/// patient is ready.
@MainActor
struct AdmitPollingTests {
    @Test func asksAgainWhilePreparingThenOpensThePatient() async {
        let service = ScriptedCases(replies: [.preparing, .preparing, .admitted(bed: "A12")])
        let app = AppState(cases: service, cards: nil)
        app.preparingPoll = .milliseconds(1)

        await app.admit(focus: FocusSelection())

        #expect(await service.admitCalls == 3)
        #expect(await service.pollingFlags == [false, true, true])
        #expect(await service.loadedBeds == ["A12"])
        #expect(!app.isAdmitting)
        #expect(!app.isPreparingCondition)
    }

    @Test func aReadyPatientIsOpenedWithoutWaiting() async {
        let service = ScriptedCases(replies: [.admitted(bed: "B7")])
        let app = AppState(cases: service, cards: nil)

        await app.admit(focus: FocusSelection())

        #expect(await service.admitCalls == 1)
        #expect(await service.loadedBeds == ["B7"])
    }

    @Test func usedUpFreeCasesOfferPlansInsteadOfAnError() async {
        let service = ScriptedCases(replies: [], needsPlan: true)
        let app = AppState(cases: service, cards: nil)

        await app.admit(focus: FocusSelection())

        #expect(app.planNeeded)
        #expect(app.problem == nil)
        #expect(!app.isAdmitting)
    }

    @Test func queuingAdmitsWithoutOpeningTheCase() async {
        let service = ScriptedCases(replies: [.admitted(bed: "C3")])
        let app = AppState(cases: service, cards: nil)

        let outcome = await app.queuePatient(focus: FocusSelection())

        #expect(outcome == .ready(nil))
        #expect(await service.loadedBeds.isEmpty)
        #expect(app.activeCase == nil)
    }

    @Test func queuingAsksOnceWhilePreparing() async {
        let service = ScriptedCases(replies: [.preparing, .admitted(bed: "D4")])
        let app = AppState(cases: service, cards: nil)

        #expect(await app.queuePatient(focus: FocusSelection()) == .preparing)
        #expect(await service.admitCalls == 1)
    }
}

/// Writing patients ahead: once per focus, one request per topic.
@MainActor
struct PrepareAheadTests {
    @Test func asksForEachTopicOnce() async {
        let service = ScriptedCases(replies: [])
        let app = AppState(cases: service, cards: nil)
        let focus = FocusSelection([.rotation(.surgery), .rotation(.neurology)])

        await app.prepareAhead(focus: focus)
        await app.prepareAhead(focus: focus)

        #expect(await service.prepared.sorted() == [StudyFocus.rotation(.neurology).stored, StudyFocus.rotation(.surgery).stored])
    }

    @Test func aMixPreparesMixedCases() async {
        let service = ScriptedCases(replies: [])
        let app = AppState(cases: service, cards: nil)

        await app.prepareAhead(focus: FocusSelection())

        #expect(await service.prepared == [StudyFocus.mix.stored])
    }

    @Test func aNewFocusPreparesAgain() async {
        let service = ScriptedCases(replies: [])
        let app = AppState(cases: service, cards: nil)

        await app.prepareAhead(focus: FocusSelection([.rotation(.surgery)]))
        await app.prepareAhead(focus: FocusSelection([.rotation(.pediatrics)]))

        #expect(await service.prepared.count == 2)
    }
}

/// Stocking the ward after onboarding: patients from the student's picks, waiting on arrival.
@MainActor
struct StockWardTests {
    private func patient(_ id: String, _ rotation: Clerkship) -> WardPatient {
        WardPatient(id: id, quote: "", meta: "", rotation: rotation, system: nil, hr: nil, bp: nil, spo2: nil, status: .new)
    }

    @Test func writesThreePatientsTakingThePickedTopicsInTurn() async {
        let service = ScriptedCases(replies: Array(repeating: .admitted(bed: "X"), count: 3))
        let app = AppState(cases: service, cards: nil)

        await app.stockWard(focus: FocusSelection([.rotation(.surgery), .rotation(.neurology)]))

        #expect(await service.admittedTopics == ["rotation:surgery", "rotation:neurology", "rotation:surgery"])
    }

    @Test func stocksOncePerFocus() async {
        let service = ScriptedCases(replies: Array(repeating: .admitted(bed: "X"), count: 6))
        let app = AppState(cases: service, cards: nil)
        let focus = FocusSelection([.rotation(.surgery)])

        await app.stockWard(focus: focus)
        await app.stockWard(focus: focus)

        #expect(await service.admitCalls == AppState.starterPatients)
    }

    @Test func patientsAlreadyWaitingInTheFocusCount() async {
        let service = ScriptedCases(replies: [.admitted(bed: "X")],
                                    ward: [patient("A1", .surgery), patient("A2", .surgery), patient("A3", .pediatrics)])
        let app = AppState(cases: service, cards: nil)

        await app.stockWard(focus: FocusSelection([.rotation(.surgery)]))

        #expect(await service.admitCalls == 1)
    }
}

/// Deleting patients: a delete the server took makes the paywall check again (it may have used up
/// the free cases); a failed one doesn't.
@MainActor
struct DeletePatientsRecheckTests {
    /// Waits for the delete, which runs in its own task, to report back.
    private func settle(_ app: AppState) async {
        for _ in 0..<200 where app.patientsDeleted == 0 && app.problem == nil {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test func aDeleteTheServerTookAsksForARecheck() async {
        let app = AppState(cases: ScriptedCases(replies: []), cards: nil)

        app.deletePatients(["A1"])
        await settle(app)

        #expect(app.patientsDeleted == 1)
    }

    @Test func aFailedDeleteDoesNot() async {
        let app = AppState(cases: ScriptedCases(replies: [], deleteFails: true), cards: nil)

        app.deletePatients(["A1"])
        await settle(app)

        #expect(app.patientsDeleted == 0)
        #expect(app.problem != nil)
    }
}

/// A case service that answers `admit` from a script and records which beds were opened.
private actor ScriptedCases: CaseService {
    func rating() async throws -> Int? { nil }
    private var replies: [AdmitOutcome]
    private(set) var admitCalls = 0
    private(set) var pollingFlags: [Bool] = []
    private(set) var loadedBeds: [String] = []
    private(set) var prepared: [String] = []
    private(set) var admittedTopics: [String] = []
    private let wardPatients: [WardPatient]
    /// Refuses every admit the way the server does once the free cases are used up (402).
    private let needsPlan: Bool
    private let deleteFails: Bool

    init(replies: [AdmitOutcome], ward: [WardPatient] = [], needsPlan: Bool = false, deleteFails: Bool = false) {
        self.replies = replies
        self.wardPatients = ward
        self.needsPlan = needsPlan
        self.deleteFails = deleteFails
    }

    struct Unused: Error {}

    func ensureSignedIn() async throws {}
    func ward() async throws -> [WardPatient] { wardPatients }
    func topicCounts() async throws -> [String: Int] { [:] }
    func gradedCases() async throws -> [GradedCase] { [] }

    func admit(focus: StudyFocus, setting: CareSetting, polling: Bool) async throws -> AdmitOutcome {
        admitCalls += 1
        if needsPlan { throw PlanRequiredError() }
        admittedTopics.append(focus.stored)
        pollingFlags.append(polling)
        return replies.isEmpty ? .preparing : replies.removeFirst()
    }

    func prepare(focus: StudyFocus, setting: CareSetting) async throws { prepared.append(focus.stored) }

    func loadCase(bed: String) async throws -> ClinicalCase {
        loadedBeds.append(bed)
        throw Unused() // opening the case isn't under test
    }

    func pastTries(bed: String) async throws -> [PastTry] { throw Unused() }
    func transcribe(attempt: String, audio: Data) async throws -> String { throw Unused() }
    func speakLatestReply(attempt: String) async throws -> Data { throw Unused() }
    func streamLatestReply(attempt: String) async throws -> AsyncThrowingStream<Data, Error> { throw Unused() }
    func askAloud(attempt: String, question: String) async throws -> SpokenAnswer { throw Unused() }
    func deletePatients(_ beds: [String]?) async throws -> Int {
        if deleteFails { throw Unused() }
        return beds?.count ?? wardPatients.count
    }
    func start(bed: String, examMode: Bool, timeLimitMinutes: Int?) async throws -> AttemptStart { throw Unused() }
    func resume(bed: String) async throws -> ResumedAttempt? { nil }
    func ask(attempt: String, question: String) async throws -> PatientAnswer { throw Unused() }
    func examine(attempt: String, maneuver: String) async throws -> String { throw Unused() }
    func order(attempt: String, test: String) async throws -> TestResult { throw Unused() }
    func submit(attempt: String, diagnosis: String, differential: [String], plan: String, focus: GradingFocus) async throws -> Grade { throw Unused() }
    func startLiveCall(attempt: String, offer: String) async throws -> LiveCall { throw Unused() }
    func logVoiceTurn(attempt: String, call: String, question: String, reply: String) async throws -> VoiceTurnOutcome { throw Unused() }
    func endLiveCall(attempt: String, call: String) async throws { throw Unused() }
}

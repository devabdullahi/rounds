import SwiftUI
import Observation

/// Career-level progress that outlives a single case, plus the student's ward of generated patients.
@MainActor
@Observable
final class AppState {
    let cases: (any CaseService)?
    /// Flashcard decks: built-in plus the student's own and generated ones.
    let flashcards: FlashcardStore

    // Sample stats until the profile screen reads them from the server.
    var rating = 1482
    var streak = 12
    var patientsSeen = 216
    var rightDiagnosisRate = 0.71
    var bestStreak = 19
    var redFlagRate = 0.72
    var rotationDone = 9
    let rotationTotal = 20

    /// The student's generated patients, newest first.
    private(set) var ward: [WardPatient] = []
    /// Every case the student has been graded on, newest first (profile breakdown and badges).
    private(set) var graded: [GradedCase] = []
    /// Conditions available per topic, keyed by `StudyFocus.stored`.
    private(set) var topicCounts: [String: Int] = [:]
    private(set) var isLoadingWard = false
    /// A new patient is being generated (takes 10–30 s).
    private(set) var isAdmitting = false
    /// The focus had no condition ready, so the server is writing its first one (a few minutes).
    private(set) var isPreparingCondition = false
    /// A patient's case is being fetched to open.
    private(set) var openingBed: String?
    var problem: String?

    var misses: [String: [Miss]] { Dictionary(uniqueKeysWithValues: ward.map { ($0.id, $0.misses) }) }
    var lastScores: [String: Int] { ward.reduce(into: [:]) { $0[$1.id] = $1.lastScore } }
    var totalMisses: Int { ward.reduce(0) { $0 + $1.misses.count } }
    var revisitPatients: [WardPatient] { ward.filter { $0.status == .revisit } }
    /// Patients still to see on the deck: new or half-done, and not skipped.
    var waiting: [WardPatient] {
        #if DEBUG
        if debugEmptyWard { return [] }
        #endif
        return ward.filter { ($0.status == .new || $0.status == .resume) && !skipped.contains($0.id) }
    }

    #if DEBUG
    /// `-screen home-empty`: shows the empty-ward card without skipping anyone for real.
    var debugEmptyWard = false

    #if DEBUG
    /// `-screen patients-select` / `patients-swipe`: the Patients tab opens in that state.
    var debugPatientsMode: String?

    /// `-screen patients-delete`: hides a row locally to show the delete animation, no server call.
    func debugHide(bed: String) {
        ward.removeAll { $0.id == bed }
    }

    /// `-screen home-preparing`: the admit card while a focus's first condition is written.
    func debugShowPreparing() {
        debugEmptyWard = true
        isAdmitting = true
        isPreparingCondition = true
    }
    #endif
    #endif

    /// Beds the student swiped away on the deck. Kept on this device so they don't come back;
    /// the patients stay on the Patients tab.
    private(set) var skipped: Set<String> = Set(UserDefaults.standard.stringArray(forKey: AppState.skippedStorageKey) ?? [])
    static let skippedStorageKey = "skippedBeds"
    /// Organ systems that have patients on the ward, for filter chips.
    /// Distinct red flags missed on the latest graded attempts, which "Include what I missed" turns into cards.
    var missedRedFlagCount: Int { Set(ward.flatMap { $0.misses.map(\.flag) }).count }

    var wardSystems: [OrganSystem] { OrganSystem.allCases.filter { s in ward.contains { $0.system == s } } }

    var lastGrade: Grade?
    var activeCase: CaseSession?
    var debugInitialPath: [CaseStep] = []

    nonisolated static let fellowThreshold = 1600
    nonisolated static let residentFloor = 1200

    init(cases: (any CaseService)?, cards: (any CardService)?) {
        self.cases = cases
        self.flashcards = FlashcardStore(service: cards)
    }

    var tierProgress: Double {
        Double(rating - Self.residentFloor) / Double(Self.fellowThreshold - Self.residentFloor)
    }
    var toNextTier: Int { max(0, Self.fellowThreshold - rating) }

    /// Conditions a focus can draw from; nil before the counts load.
    func conditionCount(for focus: StudyFocus) -> Int? {
        focus == .mix ? topicCounts.values.reduce(0, +) : (topicCounts.isEmpty ? nil : topicCounts[focus.stored] ?? 0)
    }

    // MARK: Loading

    func refresh() async {
        guard let cases else { problem = "Supabase isn't configured. Fill in Config/Secrets.xcconfig."; return }
        isLoadingWard = true
        defer { isLoadingWard = false }
        do {
            try await cases.ensureSignedIn()
            async let ward = cases.ward()
            async let counts = cases.topicCounts()
            async let graded = cases.gradedCases()
            self.ward = try await ward
            self.topicCounts = try await counts
            self.graded = try await graded
            problem = nil
            checkUnlocks()
        } catch {
            problem = error.localizedDescription
        }
    }

    /// How often to ask again while the server writes a focus's first condition. Tests shorten it.
    var preparingPoll: Duration = .seconds(15)
    /// Generation takes 2–4 minutes; past this, something went wrong on the server.
    private static let preparingGiveUp: Duration = .seconds(8 * 60)

    /// Generates a new patient for the focus (a random pick when several are chosen) and opens it.
    /// When the focus has no condition ready, waits while the server writes one, asking again.
    func admit(focus: FocusSelection) async {
        guard let cases, !isAdmitting else { return }
        isAdmitting = true
        defer { isAdmitting = false; isPreparingCondition = false }
        do {
            try await cases.ensureSignedIn()
            // Topics with no conditions would fail, so draw from the ones that have some.
            let available = focus.items.filter { (conditionCount(for: $0) ?? 1) > 0 }
            let pick = available.randomElement() ?? .mix
            let clock = ContinuousClock()
            let deadline = clock.now + Self.preparingGiveUp
            while true {
                switch try await cases.admit(focus: pick) {
                case .admitted(let bed):
                    await refresh()
                    await open(bed: bed)
                    return
                case .preparing:
                    isPreparingCondition = true
                    guard clock.now < deadline else {
                        problem = "The first case for this topic is taking longer than usual. Try again in a few minutes."
                        return
                    }
                    try await Task.sleep(for: preparingPoll)
                }
            }
        } catch is CancellationError {
            return
        } catch {
            problem = error.localizedDescription
        }
    }

    func open(bed: String) async {
        guard let cases, openingBed == nil else { return }
        openingBed = bed
        defer { openingBed = nil }
        do {
            let clinical = try await cases.loadCase(bed: bed)
            activeCase = CaseSession(clinical: clinical, service: cases)
        } catch {
            problem = error.localizedDescription
        }
    }

    /// Set when a graded case closes; the tab view switches to Patients and clears it.
    var returnToPatients = false

    /// Closes a graded case and lands on the ward.
    func finishCase() {
        returnToPatients = true
        activeCase = nil
        // The graded case may have unlocked a badge; the refresh queues its moment.
        Task { await refresh() }
    }

    /// Everything badges are judged on.
    var badgeRecord: BadgeRecord { BadgeRecord(rating: rating, bestStreak: bestStreak, cases: graded) }

    // MARK: Badge unlocks

    /// Badges whose unlock has been shown, so each card's moment plays once. Nil until the first
    /// check, which records what's already earned without celebrating it.
    private var seenBadges: Set<String>? = UserDefaults.standard.stringArray(forKey: AppState.seenBadgesStorageKey).map(Set.init)
    static let seenBadgesStorageKey = "seenBadges"
    /// Unlocks waiting to be shown, biggest first.
    private(set) var pendingUnlocks: [BadgeStatus] = []

    /// Queues any badge that unlocked since the last check.
    func checkUnlocks() {
        let statuses = BadgeCatalog.status(for: badgeRecord)
        guard let seen = seenBadges else {
            markSeen(statuses.filter(\.unlocked).map(\.id))
            return
        }
        let new = BadgeCatalog.newlyUnlocked(statuses, seen: seen)
        pendingUnlocks += new.filter { n in !pendingUnlocks.contains { $0.id == n.id } }
    }

    /// The student has seen this unlock. Only real unlocks are remembered, so a test run never
    /// spends the moment a badge will have when it's actually earned.
    func celebrated(_ status: BadgeStatus) {
        pendingUnlocks.removeAll { $0.id == status.id }
        let earned = BadgeCatalog.status(for: badgeRecord).contains { $0.id == status.id && $0.unlocked }
        if earned { markSeen([status.id]) }
    }

    private func markSeen(_ ids: [String]) {
        let all = (seenBadges ?? []).union(ids)
        seenBadges = all
        UserDefaults.standard.set(Array(all), forKey: Self.seenBadgesStorageKey)
    }

    #if DEBUG
    /// Badges page test button: plays the unlock for a random locked badge (nothing is earned).
    func debugUnlockRandomBadge() {
        let locked = BadgeCatalog.status(for: badgeRecord).filter { !$0.unlocked }
        guard let pick = (locked.isEmpty ? BadgeCatalog.status(for: badgeRecord) : locked).randomElement() else { return }
        pendingUnlocks.append(pick.asUnlocked())
    }
    #endif

    /// Removes patients from the student's history (every one when `beds` is nil). The ward
    /// updates synchronously, so a caller can animate it with `withAnimation`; the server delete
    /// follows. On failure the ward reloads from the server and the problem is shown.
    func deletePatients(_ beds: Set<String>?) {
        let removed = beds ?? Set(ward.map(\.id))
        ward.removeAll { removed.contains($0.id) }
        skipped.subtract(removed)
        UserDefaults.standard.set(Array(skipped), forKey: Self.skippedStorageKey)
        Task { await commitDelete(beds) }
    }

    private func commitDelete(_ beds: Set<String>?) async {
        guard let cases else { return }
        do {
            _ = try await cases.deletePatients(beds.map { Array($0) })
        } catch {
            let message = error.localizedDescription
            await refresh()   // clears `problem` on success, so set it after
            problem = message
        }
    }

    func skip(bed: String) {
        skipped.insert(bed)
        UserDefaults.standard.set(Array(skipped), forKey: Self.skippedStorageKey)
    }

    func record(_ grade: Grade, patient: String) {
        lastGrade = grade
        rating = grade.rating
        patientsSeen += 1
        rotationDone = min(rotationTotal, rotationDone + 1)
        if let i = ward.firstIndex(where: { $0.id == patient }) {
            ward[i].misses = grade.missedRedFlags
            ward[i].lastScore = grade.score
            ward[i].status = grade.missedRedFlags.isEmpty ? .done : .revisit
        }
    }
}

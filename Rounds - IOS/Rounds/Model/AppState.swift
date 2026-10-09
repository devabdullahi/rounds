import SwiftUI
import Observation

/// Career-level progress that outlives a single case, plus the student's ward of generated patients.
@MainActor
@Observable
final class AppState {
    let cases: (any CaseService)?
    /// Flashcard decks: built-in plus the student's own and generated ones.
    let flashcards: FlashcardStore

    /// The server's rating, loaded on refresh and updated by each grade; every account starts at 1200.
    var rating = AppState.residentFloor

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
    /// Days in a row with a graded case, ending today or yesterday (see `Streak`).
    var streak: Int {
        if showcasing { return Self.showcaseStreak }
        #if DEBUG
        if let debugStreak { return debugStreak }
        #endif
        return Streak.current(graded.map(\.submittedAt))
    }
    #if DEBUG
    /// `-screen home-streak-N`: shows an N-day streak, to check the weekly colours.
    var debugStreak: Int?
    #endif
    /// Time before the streak resets, while there is one.
    var streakTimeLeft: TimeInterval? {
        if showcasing { return 23 * 3600 }
        #if DEBUG
        if let debugStreak { return debugStreak > 0 ? 18.5 * 3600 : nil }
        #endif
        return streak > 0 ? Streak.timeLeft(graded.map(\.submittedAt)) : nil
    }
    /// The streak spotlight is open (tapped from Home's streak pill; shown over the tabs).
    var showingStreak = false

    /// The longest such run so far.
    var bestStreak: Int { showcasing ? Self.showcaseStreak : Streak.best(graded.map(\.submittedAt)) }

    // MARK: Guest showcase

    #if DEBUG
    /// Development builds, signed out: every badge shows as earned and the streak is maxed, to show
    /// the whole collection. Set by the tab view from the sign-in state. Never in release builds.
    var guestShowcase = false
    #endif
    /// The guest showcase is on (development builds only).
    var showcasing: Bool {
        #if DEBUG
        guestShowcase
        #else
        false
        #endif
    }
    /// The longest streak any badge asks for, with the flame at full heat.
    static let showcaseStreak = 100

    /// Badges as the screens show them: the real record, or all earned in the guest showcase.
    var badgeStatuses: [BadgeStatus] {
        let statuses = BadgeCatalog.status(for: badgeRecord)
        return showcasing ? statuses.map { $0.unlocked ? $0 : $0.asUnlocked() } : statuses
    }

    /// Distinct red flags missed on the latest graded attempts, which "Include what I missed" turns into cards.
    var missedRedFlagCount: Int { Set(ward.flatMap { $0.misses.map(\.flag) }).count }

    var wardSystems: [OrganSystem] { OrganSystem.allCases.filter { s in ward.contains { $0.system == s } } }

    var lastGrade: Grade?
    var activeCase: CaseSession?
    var debugInitialPath: [CaseStep] = []

    nonisolated static let residentFloor = 1200

    /// The streak reminder on this device; nil in tests and previews.
    private let reminders: (any ReminderService)?

    init(cases: (any CaseService)?, cards: (any CardService)?, reminders: (any ReminderService)? = nil) {
        self.cases = cases
        self.reminders = reminders
        self.flashcards = FlashcardStore(service: cards)
        flashcards.onProgress = { [weak self] in self?.checkUnlocks() }
    }

    var tier: RatingTier { .of(rating) }
    var tierProgress: Double { tier.progress(rating) }

    /// Graded cases, counting one just finished before the server's copy arrives.
    var patientsSeen: Int { graded.count }
    /// Share of graded cases with the right diagnosis; nil before the first one.
    var rightDiagnosisRate: Double? {
        graded.isEmpty ? nil : Double(graded.filter(\.diagnosisCorrect).count) / Double(graded.count)
    }
    /// "71%", or a dash before the first graded case.
    var rightDiagnosisText: String { rightDiagnosisRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "–" }

    /// Progress through a focus, from graded cases; nil before the condition counts load.
    func focusProgress(_ selection: FocusSelection) -> FocusProgress? {
        .of(graded, in: selection, counts: topicCounts)
    }

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
            async let rating = cases.rating()
            // Decks count toward badges too, so they load before the first unlock check.
            await flashcards.load()
            self.ward = try await ward
            self.topicCounts = try await counts
            self.graded = try await graded
            self.rating = try await rating ?? Self.residentFloor
            problem = nil
            hasLoadedRecord = true
            checkUnlocks()
            await updateReminder()
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
    /// Set from the debrief's "Make cards"; the tab view opens Cards, whose Generate sheet starts on
    /// Mistakes and clears it.
    var reviewMistakesRequested = false

    /// Closes a graded case and lands on the ward, or on a mistakes deck when the student asked for one.
    func finishCase(reviewingMistakes: Bool = false) {
        debriefSettled = false
        if reviewingMistakes { reviewMistakesRequested = true } else { returnToPatients = true }
        activeCase = nil
        Task {
            // Right after a finished case is when a streak reminder makes sense to ask about; the
            // system prompts only the first time.
            _ = await reminders?.requestPermission()
            // The graded case may have unlocked a badge; the refresh queues its moment.
            await refresh()
        }
    }

    /// Moves the reminder to two hours before the streak resets, or clears it with no streak.
    private func updateReminder() async {
        let reminder = showcasing ? nil : StreakReminder.plan(days: streak, timeLeft: streakTimeLeft)
        await reminders?.schedule(reminder)
    }

    /// Everything badges are judged on.
    var badgeRecord: BadgeRecord {
        BadgeRecord(rating: rating, bestStreak: bestStreak, cases: graded,
                    decksGenerated: flashcards.generatedDecks, notesDecks: flashcards.notesDecks,
                    missDecks: flashcards.missDecks, cardsKnown: flashcards.knownTotal)
    }

    // MARK: Badge unlocks

    /// Badges whose unlock has been shown, so each card's moment plays once. Nil until the first
    /// check, which records what's already earned without celebrating it.
    private var seenBadges: Set<String>? = UserDefaults.standard.stringArray(forKey: AppState.seenBadgesStorageKey).map(Set.init)
    static let seenBadgesStorageKey = "seenBadges"
    /// The debrief has finished revealing the grade, so a badge unlock can take the stage.
    var debriefSettled = false
    /// Unlocks waiting to be shown, biggest first.
    private(set) var pendingUnlocks: [BadgeStatus] = []

    /// Queues any badge that unlocked since the last check.
    func checkUnlocks() {
        // Nothing was earned in the showcase, so nothing is celebrated. Before the first load the
        // record is incomplete, and judging it would celebrate old badges as new.
        guard !showcasing, hasLoadedRecord else { return }
        let statuses = BadgeCatalog.status(for: badgeRecord)
        guard let seen = seenBadges else {
            markSeen(statuses.filter(\.unlocked).map(\.id))
            return
        }
        let new = BadgeCatalog.newlyUnlocked(statuses, seen: seen)
        pendingUnlocks += new.filter { n in !pendingUnlocks.contains { $0.id == n.id } }
    }

    /// Set once cases and decks have loaded, so unlock checks see the whole record.
    private var hasLoadedRecord = false

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

    /// Takes a fresh grade into the record at once, so badges it earns unlock on the debrief, at the
    /// moment of success, not later on another tab. The next refresh replaces it with the server's copy.
    func record(_ grade: Grade, session: CaseSession) {
        let patient = session.clinical.bed
        graded.insert(GradedCase(id: "local-\(UUID().uuidString)", submittedAt: .now, score: grade.score,
                                 diagnosisCorrect: grade.diagnosisCorrect, missedRedFlags: grade.missedRedFlags.count,
                                 clerkship: session.clinical.clerkship, system: session.clinical.system, breakdown: [:],
                                 examMode: session.examMode, timed: session.isTimed, caseID: patient), at: 0)
        checkUnlocks()
        lastGrade = grade
        rating = grade.rating
        if let i = ward.firstIndex(where: { $0.id == patient }) {
            ward[i].misses = grade.missedRedFlags
            ward[i].lastScore = grade.score
            ward[i].status = grade.missedRedFlags.isEmpty ? .done : .revisit
        }
    }
}

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
    /// The focus whose patients were last asked to be written ahead, so revisiting Home doesn't ask
    /// again. After each admit the server queues the next one itself.
    private var preparedFocus: String?
    /// The focus the ward was last stocked for after onboarding, so it's stocked once per focus.
    private var stockedFocus: String?
    var problem: String?
    /// Set when the server refused a new patient because the free cases are used up; the root view
    /// offers plans (Superwall's paywall) and clears it. Patients already written stay playable.
    var planNeeded = false

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

    /// Beds the student swiped away on the deck. Kept on this device so they don't come back;
    /// the patients stay on the Patients tab.
    private(set) var skipped: Set<String> = Set(UserDefaults.standard.stringArray(forKey: AppState.skippedStorageKey) ?? [])
    static let skippedStorageKey = "skippedBeds"
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

    /// Organ systems that have patients on the ward, for filter chips.
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
    /// Cases graded since midnight on this device, for the daily goal on Home.
    var gradedToday: Int { graded.filter { Calendar.current.isDateInToday($0.submittedAt) }.count }
    /// A student who hasn't finished a case yet, once their record has loaded: Home points them at
    /// their first patient instead of greeting them by shift, so onboarding never ends on a blank.
    var isFirstPatient: Bool { hasLoadedRecord && graded.isEmpty }
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
            await loadHistoryProgress()
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

    /// Key history found on each half-done patient, for the progress dashes on Patients. Only the
    /// server knows which facts are key, so it asks the resume endpoint; a failure just leaves no dashes.
    private func loadHistoryProgress() async {
        guard let cases else { return }
        let beds = ward.filter { $0.status == .resume }.map(\.id)
        let found = await withTaskGroup(of: (String, Int?).self) { group in
            for bed in beds {
                group.addTask { (bed, try? await cases.resume(bed: bed)?.coverage.got) }
            }
            return await group.reduce(into: [String: Int]()) { if let got = $1.1 { $0[$1.0] = got } }
        }
        for i in ward.indices { if let got = found[ward[i].id] { ward[i].historyFound = got } }
    }

    /// How often to check for a case the server is writing in the background. Tests shorten it.
    var preparingPoll: Duration = .seconds(2)
    /// Generation takes 2–4 minutes; past this, something went wrong on the server.
    private static let preparingGiveUp: Duration = .seconds(8 * 60)

    /// Generates a new patient for the focus (a random pick when several are chosen), in the
    /// student's care setting, and opens it.
    /// When the focus has no condition ready, waits while the server writes one, asking again.
    func admit(focus: FocusSelection) async {
        guard let cases, !isAdmitting else { return }
        isAdmitting = true
        defer { isAdmitting = false; isPreparingCondition = false }
        do {
            try await cases.ensureSignedIn()
            let pick = pickTopic(from: focus)
            let setting = CareSetting.current
            let clock = ContinuousClock()
            let deadline = clock.now + Self.preparingGiveUp
            var polling = false
            while true {
                switch try await cases.admit(focus: pick, setting: setting, polling: polling) {
                case .admitted(let bed):
                    await refresh()
                    await open(bed: bed)
                    return
                case .preparing:
                    isPreparingCondition = true
                    polling = true
                    guard clock.now < deadline else {
                        problem = "The first case for this topic is taking longer than usual. Try again in a few minutes."
                        return
                    }
                    try await Task.sleep(for: preparingPoll)
                }
            }
        } catch is CancellationError {
            return
        } catch is PlanRequiredError {
            planNeeded = true
        } catch {
            problem = error.localizedDescription
        }
    }

    /// Most topics written ahead per focus: each costs a background case, and students rarely pick more.
    private static let prepareLimit = 4

    /// Asks the server to write a patient ahead for each topic in the focus, so even the first case
    /// in a topic opens instantly. Once per focus; failures only cost the head start.
    func prepareAhead(focus: FocusSelection) async {
        // The setting is part of the key: a new setting needs its own patients written ahead.
        let setting = CareSetting.current
        let key = focus.stored + "@" + setting.rawValue
        guard let cases, preparedFocus != key else { return }
        preparedFocus = key
        let topics = focus.isMix ? [StudyFocus.mix] : Array(focus.items.prefix(Self.prepareLimit))
        do {
            try await cases.ensureSignedIn()
            await withTaskGroup(of: Void.self) { group in
                // Skip only topics known to be empty; before the counts load, every topic is tried.
                for topic in topics where topicCounts.isEmpty || (conditionCount(for: topic) ?? 1) > 0 {
                    group.addTask { try? await cases.prepare(focus: topic, setting: setting) }
                }
            }
        } catch {
            preparedFocus = nil
        }
    }

    /// Patients a new student finds waiting after onboarding.
    static let starterPatients = 3

    /// Puts patients from the student's picks on the ward without opening them, so the deck isn't
    /// empty on arrival: up to `starterPatients`, counting ones already waiting that fit, taking the
    /// picked topics in turn. Once per focus; a topic still being written is skipped, not waited on.
    func stockWard(focus: FocusSelection) async {
        guard let cases, stockedFocus != focus.stored else { return }
        stockedFocus = focus.stored
        do {
            try await cases.ensureSignedIn()
            await refresh()
            let missing = Self.starterPatients - waiting.filter { $0.fits(focus) }.count
            guard missing > 0 else { return }
            let topics = focus.isMix ? [StudyFocus.mix] : focus.items.filter { (conditionCount(for: $0) ?? 1) > 0 }
            guard !topics.isEmpty else { return }
            var added = 0
            for i in 0..<missing {
                if case .admitted = try await cases.admit(focus: topics[i % topics.count], setting: .current, polling: false) {
                    added += 1
                }
            }
            if added > 0 { await refresh() }
        } catch {
            // A failed start only costs the head start; the deck's dice still admit a patient.
            stockedFocus = nil
        }
    }

    /// Admits a patient onto the ward without opening the case, for Shortcuts and Siri. One try: a
    /// topic whose first case is still being written answers `.preparing` rather than waiting minutes.
    func queuePatient(focus: FocusSelection) async -> QueueOutcome {
        guard let cases else { return .failed("Rounds isn't connected to its server.") }
        do {
            try await cases.ensureSignedIn()
            switch try await cases.admit(focus: pickTopic(from: focus), setting: .current, polling: false) {
            case .admitted(let bed):
                await refresh()
                return .ready(ward.first { $0.id == bed })
            case .preparing:
                return .preparing
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// One topic from the focus (a random pick when several are chosen). Topics with no conditions
    /// would fail, so it draws from the ones that have some.
    private func pickTopic(from focus: FocusSelection) -> StudyFocus {
        focus.items.filter { (conditionCount(for: $0) ?? 1) > 0 }.randomElement() ?? .mix
    }

    func open(bed: String) async {
        guard let cases, openingBed == nil else { return }
        openingBed = bed
        defer { openingBed = nil }
        do {
            let clinical = try await cases.loadCase(bed: bed)
            let session = CaseSession(clinical: clinical, service: cases)
            // The door note can still switch it; this is just where it starts.
            session.examMode = Preferences.examByDefault
            // A case left mid-way continues where it stopped. If the lookup fails, the case still
            // opens, just from the start.
            if let left = try? await cases.resume(bed: bed) { session.restore(left) }
            activeCase = session
        } catch is PlanRequiredError {
            planNeeded = true
        } catch {
            problem = error.localizedDescription
        }
    }

    /// Set when a graded case closes; the tab view switches to Patients and clears it.
    var returnToPatients = false
    /// Set from the debrief's "Make cards"; the tab view opens Cards, whose Generate sheet starts on
    /// Mistakes and clears it.
    var reviewMistakesRequested = false
    /// Set by Siri's "next patient"; the tab view shows Today, where the admission plays out.
    var showTodayRequested = false

    /// Closes a graded case and lands on the ward, or on a mistakes deck when the student asked for one.
    /// Bumped each time a graded case is left, so the paywall can check again: a free case ends here.
    private(set) var casesFinished = 0
    /// Set once, after the student's first graded case (and the reminder prompt it brings): the
    /// root view then asks for an App Store rating and clears it. Apple decides whether the sheet shows.
    private(set) var ratingDue = false
    /// Whether this phone has asked for a rating yet. Kept across sign-outs: it's the phone's ask.
    static let ratingAskedStorageKey = "ratingAsked"

    func finishCase(reviewingMistakes: Bool = false) {
        casesFinished += 1
        debriefSettled = false
        if reviewingMistakes { reviewMistakesRequested = true } else { returnToPatients = true }
        activeCase = nil
        Task {
            // Right after a finished case is when a streak reminder makes sense to ask about; the
            // system prompts only the first time.
            _ = await reminders?.requestPermission()
            // The graded case may have unlocked a badge; the refresh queues its moment.
            await refresh()
            // After the first patient, once the reminder prompt is answered: one rating request.
            if !UserDefaults.standard.bool(forKey: Self.ratingAskedStorageKey) {
                UserDefaults.standard.set(true, forKey: Self.ratingAskedStorageKey)
                ratingDue = true
            }
        }
    }

    /// The rating request was handed to the system.
    func ratingAsked() { ratingDue = false }

    /// Tells the student something finished while the app wasn't watching (a deck made from Siri).
    func announce(title: String, body: String) async {
        await reminders?.announce(title: title, body: body)
    }

    /// Turns on the daily practice reminder the student picked: asks for permission first (the
    /// system prompts only once) and schedules it only if allowed. False when notifications are off.
    func setPracticeReminder(_ reminder: PracticeReminder) async -> Bool {
        guard let reminders, await reminders.requestPermission() else { return false }
        await reminders.scheduleDaily(reminder)
        return true
    }

    /// Moves the reminder to two hours before the streak resets, or clears it with no streak or
    /// when the student turned streak alerts off. Settings calls it when that switch changes.
    func updateReminder() async {
        let alertsOn = !showcasing && Preferences.streakAlerts
        let reminder = alertsOn ? StreakReminder.plan(days: streak, timeLeft: streakTimeLeft) : nil
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
    /// Set when onboarding has just made this account, so its "Beginning" badge is celebrated once.
    /// Only that run knows the account is new: signing back in to an account that hasn't finished a
    /// case yet mustn't replay the welcome.
    var accountJustCreated = false
    /// The student chose "Accept all": the waiting unlocks show together, lined up, instead of one by one.
    var showingAllUnlocks = false

    /// Forgets the last account on sign-out: its patients, grades, rating, open case, badge moments
    /// and study state. Device-wide keys (badges seen, patients skipped, cards known) are cleared too,
    /// so the next account neither inherits them nor sees its own badges replay; the first load after
    /// sign-in records what that account has already earned without celebrating it.
    func reset() {
        ward = []
        graded = []
        rating = Self.residentFloor
        lastGrade = nil
        activeCase = nil
        problem = nil
        pendingUnlocks = []
        showingAllUnlocks = false
        debriefSettled = false
        hasLoadedRecord = false
        preparedFocus = nil
        seenBadges = nil
        accountJustCreated = false
        UserDefaults.standard.removeObject(forKey: Self.seenBadgesStorageKey)
        skipped = []
        UserDefaults.standard.removeObject(forKey: Self.skippedStorageKey)
        returnToPatients = false
        reviewMistakesRequested = false
        showTodayRequested = false
        flashcards.reset()
    }

    /// Queues any badge that unlocked since the last check.
    func checkUnlocks() {
        // Nothing was earned in the showcase, so nothing is celebrated. Before the first load the
        // record is incomplete, and judging it would celebrate old badges as new.
        guard !showcasing, hasLoadedRecord else { return }
        let statuses = BadgeCatalog.status(for: badgeRecord)
        guard let seen = seenBadges else {
            // First check for this account on this phone: what it already holds is recorded quietly,
            // except a brand-new account's welcome badge, which is the one unlock it should see.
            let first = BadgeCatalog.firstLook(statuses, newAccount: accountJustCreated)
            markSeen(first.quiet)
            pendingUnlocks += first.celebrate
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

    /// "Add all to collection": every waiting unlock counts as seen.
    func celebratedAll() {
        for status in pendingUnlocks { celebrated(status) }
        showingAllUnlocks = false
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

    /// `-screen badge-unlock-many`: several unlocks queued at once, for "Accept all".
    func debugUnlockSeveral(_ count: Int) {
        pendingUnlocks += BadgeCatalog.status(for: badgeRecord).shuffled().prefix(count).map { $0.asUnlocked() }
    }

    /// Plays one badge's unlock by id (the badge-unlock-beginning screen).
    func debugUnlock(_ id: String) {
        guard let status = BadgeCatalog.status(for: badgeRecord).first(where: { $0.id == id }) else { return }
        pendingUnlocks.append(status.asUnlocked())
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
                                 clerkship: session.clinical.clerkship, system: session.clinical.system, breakdown: grade.breakdown,
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

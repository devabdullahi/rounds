import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Onboarding (each page, on arrival)
 *
 *    0ms   main card / avatar pops in, scale 0.85 → 1
 *   60ms+  the rest of the hero art follows, ~60ms apart
 *  150ms   (exam-ready page) "with Rounds" line draws (900ms)
 *  900ms   (exam-ready page) "With Rounds" label pops
 *  (plan page has its own storyboard in PlanHero)
 *
 * One carousel for every step, so swiping, Next and Back all slide the same way. The
 * background cross-fades between pages (mint, page colour for the focus picker, blush for
 * the promise). Question pages have no art: the question on top, answers as a list (no
 * entrance animation). Pages past an unanswered step aren't added yet, so a swipe can't skip a
 * choice (year, goal, focus, hardest part, red flag, name, the AI consent, then the account when
 * onboarding began signed out). After the promise the carousel locks. Reduce Motion: final states, instant
 * page changes.
 * ───────────────────────────────────────────────────────── */

/// New-student onboarding: intro pages interleaved with the questions (year, study goal, focus,
/// name), the plan, making the account and the promise, as one carousel. The typed name goes on
/// the account as soon as there is one. Started from
/// "Get Started" it's signed out until the account page; started by logging in with an account
/// that never finished onboarding, that page is skipped.
struct OnboardingView: View {
    @Environment(AuthModel.self) private var auth
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(SchoolYear.storageKey) private var yearStored = ""
    @AppStorage(StudyGoal.storageKey) private var goalStored = ""
    @AppStorage(StudyFocus.storageKey) private var focusStored = ""
    @AppStorage(CareSetting.storageKey) private var settingStored = ""
    @AppStorage(ProfileName.storageKey) private var nameStored = ""
    @AppStorage(PracticeReminder.storageKey) private var reminderStored = ""
    @AppStorage(StudyStruggle.storageKey) private var strugglesStored = ""
    @AppStorage(AIConsent.storageKey) private var consentStored = AIConsent.withdrawn

    /// The page in view. A paging scroll view, not a page-style TabView: TabView swaps pages
    /// instantly when Next sets the selection, so Next and a swipe would move differently.
    @State private var visible: OnboardingPage? = .patients
    @State private var seen: Set<OnboardingPage> = []
    @State private var pick = FocusSelection()
    @State private var mixChosen = false
    @State private var heart = HoldToCommit()
    @State private var holdingHeart = false
    /// The red-flag quiz answer (an option's text), nil until the student taps one.
    @State private var redFlagPick: String?
    /// Set on arrival: whether this run includes the account page.
    @State private var startedSignedOut = false

    private var page: OnboardingPage { visible ?? .patients }
    private var yearPicked: Bool { SchoolYear(stored: yearStored) != nil }
    private var goalPicked: Bool { StudyGoal(stored: goalStored) != nil }
    private var focusReady: Bool { !pick.isMix || mixChosen }
    private var reminderPicked: PracticeReminder? { PracticeReminder(stored: reminderStored) }
    private var nameTyped: Bool { ProfileName.clean(nameStored) != nil }
    private var consented: Bool { AIConsent.isGiven(stored: consentStored) }

    /// The pages a swipe may reach: everything up to and including the first unanswered choice.
    private var pages: [OnboardingPage] {
        var reachable: [OnboardingPage] = []
        for p in OnboardingPage.allCases {
            if p == .account && !startedSignedOut { continue }
            reachable.append(p)
            if !answered(p) { break }
        }
        return reachable
    }

    /// Whether a page's choice is made, so the pages after it may be shown.
    private func answered(_ p: OnboardingPage) -> Bool {
        switch p {
        case .schoolYear: yearPicked
        case .studyGoal: goalPicked
        case .focus: focusReady
        case .struggles: !StudyStruggle.decode(strugglesStored).isEmpty
        case .redFlag: redFlagPick != nil
        case .name: nameTyped
        case .aiConsent: consented
        case .account: auth.account != nil
        default: true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingTopBar(total: stepCount, current: stepNumber,
                             onBack: page == .patients || heart.isDone ? nil : { step(-1) })
                .padding(.horizontal, 20)

            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(pages, id: \.self) { p in
                        content(p)
                            .containerRelativeFrame(.horizontal)
                            .id(p)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $visible)
            .scrollDisabled(heart.isDone)

            bottom
                .padding(.bottom, 12)
                .animation(.easeOut(duration: 0.25), value: heart.isDone)
        }
        .background { background.animation(.easeInOut(duration: 0.35), value: page) }
        .onChange(of: page, initial: true) { _, p in
            seen.insert(p)
            auth.reachedOnboarding(page: String(describing: p), step: stepNumber)
        }
        // The focus picker saves as it changes, so swiping on to the promise keeps the latest picks.
        .onChange(of: pick) { _, new in if focusReady { focusStored = new.stored } }
        .onChange(of: mixChosen) { _, _ in if focusReady { focusStored = pick.stored } }
        .onChange(of: goalStored) { _, new in
            if let goal = StudyGoal(stored: new) { settingStored = goal.careSetting.rawValue }
        }
        // Once there's an account: the typed name replaces whatever Apple or Google gave it, and
        // (after the AI consent) patients from the student's picks start being written, so some
        // wait when onboarding ends.
        .onChange(of: page) { old, _ in
            if old == .name { Task { await saveName() } }
            if old == .focus { stockWard() }
        }
        .onChange(of: auth.account?.id) { _, id in
            guard id != nil else { return }
            Task { await saveName() }
            stockWard()
        }
        // Signed in from the start (no account page): the first patients wait for the consent.
        .onChange(of: consentStored) { _, _ in stockWard() }
        .onAppear { startedSignedOut = auth.account == nil }
        #if DEBUG
        .onAppear { debugStart() }
        #endif
    }

    /// Steps in this run, for the progress bar: the account page counts only when it's shown.
    private var stepCount: Int { OnboardingPage.allCases.count - (startedSignedOut ? 0 : 1) }
    private var stepNumber: Int {
        page.rawValue + 1 - (!startedSignedOut && page.rawValue > OnboardingPage.account.rawValue ? 1 : 0)
    }

    // MARK: Pages

    @ViewBuilder
    private func content(_ p: OnboardingPage) -> some View {
        switch p {
        case .focus:
            FocusPage(pick: $pick, mixChosen: $mixChosen)
        case .tryInterview: TryInterviewPage(shown: seen.contains(p))
        case .schoolYear: SchoolYearPage(shown: seen.contains(p))
        case .studyGoal: StudyGoalPage(shown: seen.contains(p))
        case .careSetting: CareSettingPage(shown: seen.contains(p))
        case .struggles: StrugglePage(shown: seen.contains(p))
        case .redFlag: RedFlagPage(shown: seen.contains(p), picked: $redFlagPick)
        case .talkStyle: TalkStylePage(shown: seen.contains(p))
        case .caseMode: CaseModePage(shown: seen.contains(p))
        case .caseTimer: CaseTimerPage(shown: seen.contains(p))
        case .name: NamePage(shown: seen.contains(p), active: page == .name) { step(1) }
        case .dailyGoal: DailyGoalPage(shown: seen.contains(p))
        case .reminder: ReminderPage(shown: seen.contains(p))
        case .aiConsent: AIConsentPage(shown: seen.contains(p))
        case .pledge:
            PledgePage(heart: $heart, isHolding: $holdingHeart)
        case .account:
            VStack(spacing: 14) {
                if let headline = p.headline { OnboardingHeadline(text: headline) }
                Spacer(minLength: 0)
                AppIcon(.brandMark, size: 72)
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                ProviderButtons(busy: auth.signingInWith) { provider in Task { await signUp(with: provider) } }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        default:
            VStack(spacing: 14) {
                hero(p).frame(maxHeight: 420)
                if let headline = p.headline { OnboardingHeadline(text: headline) }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }

    @ViewBuilder
    private func hero(_ p: OnboardingPage) -> some View {
        let shown = seen.contains(p)
        switch p {
        case .patients: PatientsHero(shown: shown)
        case .graded: GradedHero(shown: shown)
        case .promise: PromiseHero(shown: shown)
        case .examReady: ExamReadyHero(shown: shown)
        case .missCards: MissCardHero(shown: shown)
        case .progress: ProgressHero(shown: shown)
        case .plan: PlanHero(shown: shown)
        default: EmptyView()
        }
    }

    @ViewBuilder
    private var background: some View {
        switch page {
        case .focus: Theme.bg.ignoresSafeArea()
        case .pledge: HeroWash(tint: Theme.heroBlush)
        default: HeroWash()
        }
    }

    // MARK: Bottom control

    @ViewBuilder
    private var bottom: some View {
        switch page {
        case .reminder:
            VStack(spacing: 4) {
                OnboardingNextButton(title: "Turn On Reminders", enabled: reminderPicked != nil) {
                    guard let reminder = reminderPicked else { return }
                    Task {
                        // iOS asks for permission here; the page moves on whatever the answer.
                        _ = await app.setPracticeReminder(reminder)
                        step(1)
                    }
                }
                Button("Not now") { step(1) }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(minHeight: 44)
            }
        case .focus:
            OnboardingNextButton(title: "Continue", enabled: focusReady) { step(1) }
        case .aiConsent:
            // Agreeing is the only way on: the carousel ends here until it's recorded.
            OnboardingNextButton(title: "I agree") {
                consentStored = AIConsent.agreed
                // The next page joins the carousel only once the agreement is stored and laid out;
                // a scroll position set before that is dropped.
                Task {
                    try? await Task.sleep(for: .milliseconds(120))
                    step(1)
                }
            }
        case let p where p.isQuestion:
            OnboardingNextButton(title: "Continue", enabled: answered(p)) { step(1) }
        case .account:
            // Signed in already (they came back a page): just move on. Otherwise the page's own buttons.
            if auth.account != nil {
                OnboardingNextButton { step(1) }
            } else {
                Text("For practice only. Fictional patients, not medical advice.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .frame(height: 60)
            }
        case .pledge:
            if heart.isDone {
                OnboardingNextButton(title: "Get Started") { auth.finishOnboarding(answers: .stored(redFlagPick: redFlagPick)) }
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.95)))
            } else {
                Text(holdingHeart ? "Keep holding\u{2026}" : "Press and hold")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.warnText)
                    .frame(height: 60)
                    .accessibilityHidden(true)   // the heart's own hint covers it
            }
        default:
            OnboardingNextButton { step(1) }
        }
    }

    /// Starts writing the student's first patients, in the background: it outlives this screen.
    /// Not before the AI consent: writing a patient sends the student's picks to an AI provider.
    private func stockWard() {
        guard auth.account != nil, focusReady, consented else { return }
        let focus = pick
        Task { await app.stockWard(focus: focus) }
    }

    /// Puts the typed name on the account. Nothing to do until both exist; `rename` skips an
    /// unchanged name.
    private func saveName() async {
        guard auth.account != nil, nameTyped else { return }
        _ = await auth.rename(nameStored)
    }

    /// Makes (or finds) the account. One that already finished onboarding goes straight in;
    /// a new one goes on to the promise.
    private func signUp(with provider: SocialProvider) async {
        guard let account = await auth.continueWith(provider) else { return }
        if account.onboarded { auth.finishSignIn() } else { step(1) }
    }

    /// One page on or back; slides like a swipe, or switches instantly with Reduce Motion.
    private func step(_ by: Int) {
        guard let index = pages.firstIndex(of: page), pages.indices.contains(index + by) else { return }
        withAnimation(reduceMotion ? nil : Springs.slide) { visible = pages[index + by] }
    }

    #if DEBUG
    /// `-screen` names that open onboarding on a given page.
    private static let debugPages: [String: OnboardingPage] = [
        "onboarding-intro": .patients, "onboarding-try": .tryInterview, "onboarding-year": .schoolYear, "onboarding-goal": .studyGoal,
        "onboarding-graph": .examReady, "onboarding-graded": .graded, "onboarding": .focus, "focus-system": .focus,
        "onboarding-name": .name,
        "onboarding-setting": .careSetting, "onboarding-redflag": .redFlag, "onboarding-cards": .missCards,
        "onboarding-struggles": .struggles, "onboarding-talk": .talkStyle, "onboarding-mode": .caseMode,
        "onboarding-timer": .caseTimer, "onboarding-progress": .progress, "onboarding-daily": .dailyGoal,
        "onboarding-reminder": .reminder, "onboarding-promise": .promise, "onboarding-plan": .plan,
        "onboarding-consent": .aiConsent, "onboarding-account": .account, "onboarding-heart": .pledge, "onboarding-promised": .pledge,
    ]

    private func debugStart() {
        guard let screen = DebugLaunch.screen else { return }
        if screen == "onboarding-to-goal" {
            // Next twice, from the year through the goal into the exam-ready page.
            visible = .schoolYear
            if !yearPicked { yearStored = SchoolYear.ms3.rawValue }
            if !goalPicked { goalStored = StudyGoal.step2CK.rawValue }
            Task {
                for _ in 0..<2 { try? await Task.sleep(for: .seconds(1.5)); step(1) }
            }
            return
        }
        guard let target = Self.debugPages[screen] else { return }
        // Answer every question before the target, so the carousel can reach it.
        if target.rawValue > OnboardingPage.schoolYear.rawValue, !yearPicked { yearStored = SchoolYear.ms3.rawValue }
        if target.rawValue > OnboardingPage.studyGoal.rawValue, !goalPicked { goalStored = StudyGoal.step2CK.rawValue }
        if target.rawValue >= OnboardingPage.focus.rawValue {
            pick = FocusSelection([.rotation(.internalMedicine), .rotation(.neurology)])
        }
        if target.rawValue > OnboardingPage.struggles.rawValue, StudyStruggle.decode(strugglesStored).isEmpty {
            strugglesStored = StudyStruggle.whatToAsk.rawValue
        }
        if target.rawValue > OnboardingPage.redFlag.rawValue, redFlagPick == nil {
            redFlagPick = RedFlagQuiz.chestPain.answer?.id
        }
        if target.rawValue > OnboardingPage.name.rawValue, !nameTyped { nameStored = "Jordan" }
        if target.rawValue > OnboardingPage.aiConsent.rawValue, !consented { consentStored = AIConsent.agreed }
        // The promise comes after the account, so these screens start with the sample one.
        // Session restore can clear the sample right after launch, so also run as if onboarding
        // began signed in: no account page to gate the promise.
        if target == .pledge { auth.debugUse(DebugLaunch.sampleAccount); startedSignedOut = false }
        if screen == "onboarding-promised" { heart.complete() }
        // After a beat: the pages up to the target exist only once the answers above are laid out,
        // and a scroll position set before that is dropped.
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            visible = target
        }
    }
    #endif
}

import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Onboarding (each page, on arrival)
 *
 *    0ms   question pages: rows enter in turn (QuestionEntrance)
 *    0ms   value pages: their own storyboards (BlankedReplyPage, CountdownPage, RealityCheckPage,
 *          SettingUpPage, StudyPlanPage)
 *
 * One carousel for every step, so swiping, Next and Back all slide the same way. The
 * background cross-fades between pages (mint, blush for the promise). Pages past an unanswered
 * step aren't added yet, so a swipe can't skip a choice (year, goal, then the account when
 * onboarding began signed out). The exam date is left out for goals that aren't an exam, and the
 * reality check without an exam month. After the promise the carousel locks.
 * Reduce Motion: final states, instant page changes.
 * ───────────────────────────────────────────────────────── */

/// New-student onboarding, the design canvas's flow: year, goal and what to practice, the answers
/// read back (exam tips, when the exam is), how sure they feel and a reality check, their pace, a
/// "setting up" beat, their plan, the account, where they heard about Rounds, and the promise, as
/// one carousel. Started from "Get Started" it's signed out until the account page; started by
/// logging in with an account that never finished onboarding, that page is skipped. The AI
/// consent comes after, before anything reaches an AI provider (RootView).
struct OnboardingView: View {
    @Environment(AuthModel.self) private var auth
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(SchoolYear.storageKey) private var yearStored = ""
    @AppStorage(StudyGoal.storageKey) private var goalStored = ""
    @AppStorage(StudyFocus.storageKey) private var focusStored = ""
    @AppStorage(CareSetting.storageKey) private var settingStored = ""
    @AppStorage(HeardFrom.storageKey) private var heardStored = ""
    @AppStorage(ExamMonth.storageKey) private var examStored = ""
    @AppStorage(DiagnosisConfidence.storageKey) private var confidenceStored = 0
    @AppStorage(BlankFrequency.storageKey) private var blankStored = ""
    @AppStorage(PracticeReminder.preferredKey) private var studyTimeStored = ""
    @AppStorage(AIConsent.storageKey) private var consentStored = AIConsent.withdrawn

    /// The page in view. A paging scroll view, not a page-style TabView: TabView swaps pages
    /// instantly when Next sets the selection, so Next and a swipe would move differently.
    @State private var visible: OnboardingPage? = .schoolYear
    @State private var seen: Set<OnboardingPage> = []
    @State private var heart = HoldToCommit()
    @State private var holdingHeart = false
    /// Optional questions the student skipped: they count as answered, with nothing saved.
    @State private var skipped: Set<OnboardingPage> = []
    /// Pages whose task the student has done (the practice pick); their Continue waits for it.
    @State private var finished: Set<OnboardingPage> = []
    /// Set on arrival: whether this run includes the account page.
    @State private var startedSignedOut = false
    /// Set on first appear, so coming back to this page never clears the answers mid-flow.
    @State private var started = false

    private var page: OnboardingPage { visible ?? .schoolYear }
    private var goal: StudyGoal? { StudyGoal(stored: goalStored) }
    private var consented: Bool { AIConsent.isGiven(stored: consentStored) }

    /// Pages in this run: the account only when it began signed out, the exam date only for an
    /// exam goal, the countdown and reality check only once there's an exam month to count down to.
    private var flow: [OnboardingPage] {
        OnboardingPage.allCases.filter { p in
            switch p {
            case .account: startedSignedOut
            case .examDate: goal.map { [.step1, .step2CK, .shelf, .osce].contains($0) } ?? true
            case .countdown, .realityCheck: ExamMonth(stored: examStored) != nil
            default: true
            }
        }
    }

    /// The pages a swipe may reach: everything up to and including the first unanswered choice.
    private var pages: [OnboardingPage] {
        var reachable: [OnboardingPage] = []
        for p in flow {
            reachable.append(p)
            if !answered(p) { break }
        }
        return reachable
    }

    /// Whether a page's choice is made, so the pages after it may be shown.
    private func answered(_ p: OnboardingPage) -> Bool {
        if skipped.contains(p) { return true }
        return switch p {
        case .schoolYear: SchoolYear(stored: yearStored) != nil
        case .studyGoal: goal != nil
        case .examDate: !examStored.isEmpty
        case .heardFrom: HeardFrom(rawValue: heardStored) != nil
        case .account: auth.account != nil
        case .practice: finished.contains(p)
        case .confidence: DiagnosisConfidence(stored: confidenceStored) != nil
        case .blanked: BlankFrequency(stored: blankStored) != nil
        case .studyTime: PracticeReminder(stored: studyTimeStored) != nil
        default: true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingTopBar(total: flow.count, current: (flow.firstIndex(of: page) ?? 0) + 1,
                             onBack: page == flow.first || heart.isDone ? nil : { step(-1) })
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
            auth.reachedOnboarding(page: String(describing: p), step: (flow.firstIndex(of: p) ?? 0) + 1)
        }
        .onChange(of: goalStored) { _, new in
            if let goal = StudyGoal(stored: new) { settingStored = goal.careSetting.rawValue }
        }
        // Once there's an account (and the AI consent), patients start being written, so some wait
        // when onboarding ends.
        .onChange(of: auth.account?.id) { _, id in if id != nil { stockWard() } }
        .onChange(of: consentStored) { _, _ in stockWard() }
        .onAppear {
            guard !started else { return }
            started = true
            startedSignedOut = auth.account == nil
            #if DEBUG
            // A `-screen` past the first page keeps the sample answers it needs to get there.
            if (DebugLaunch.screen.flatMap { Self.debugPages[$0] } ?? .schoolYear) == .schoolYear { OnboardingAnswers.clearPicks() }
            debugStart()
            #else
            OnboardingAnswers.clearPicks()
            #endif
        }
    }

    // MARK: Pages

    @ViewBuilder
    private func content(_ p: OnboardingPage) -> some View {
        let shown = seen.contains(p)
        switch p {
        case .schoolYear: SchoolYearPage(shown: shown)
        case .studyGoal: StudyGoalPage(shown: shown)
        case .practice: PracticePage(shown: shown) { finished.insert(.practice) }
        case .blanked: BlankedPage(shown: shown)
        case .blankedReply: BlankedReplyPage(shown: shown)
        case .examDate: ExamDatePage(shown: shown)
        case .countdown: CountdownPage(shown: shown)
        case .confidence: ConfidencePage(shown: shown)
        case .realityCheck: RealityCheckPage(shown: shown)
        case .pace: PacePage(shown: shown)
        case .studyTime: StudyTimePage(shown: shown)
        case .settingUp: SettingUpPage(shown: shown) { if page == .settingUp { step(1) } }
        case .plan: StudyPlanPage(shown: shown)
        case .heardFrom: HeardFromPage(shown: shown)
        case .pledge: PledgePage(heart: $heart, isHolding: $holdingHeart)
        case .account:
            AccountPage(busy: auth.signingInWith) { provider in Task { await signUp(with: provider) } }
        }
    }

    @ViewBuilder
    private var background: some View {
        switch page {
        case .pledge: HeroWash(tint: Theme.heroBlush)
        default: Theme.surface.ignoresSafeArea()
        }
    }

    // MARK: Bottom control

    @ViewBuilder
    private var bottom: some View {
        switch page {
        case let p where p.isSkippable:
            VStack(spacing: 4) {
                OnboardingNextButton(title: nextTitle(p), enabled: answered(p)) { step(1) }
                Button(p.skipTitle) {
                    skipped.insert(p)
                    later { step(1) }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .frame(minHeight: 44)
                .opacity(answered(p) && !skipped.contains(p) ? 0 : 1)
                .disabled(answered(p) && !skipped.contains(p))
            }
        case .settingUp:
            // It moves on by itself; the space keeps the page from jumping.
            Color.clear.frame(height: 60)
        case let p where p.isQuestion:
            OnboardingNextButton(title: nextTitle(p), enabled: answered(p)) { step(1) }
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
                OnboardingNextButton(title: "Get started") { auth.finishOnboarding(answers: .stored(redFlagPick: nil)) }
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.95)))
            } else {
                Text(holdingHeart ? "Keep holding\u{2026}" : "Press and hold")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
                    .frame(height: 60)
                    .accessibilityHidden(true)   // the heart's own hint covers it
            }
        default:
            OnboardingNextButton(title: nextTitle(page), enabled: answered(page)) { step(1) }
        }
    }

    /// What the page's main button says: "Continue", except at the three milestones, where it
    /// names what happens next.
    private func nextTitle(_ p: OnboardingPage) -> String {
        switch p {
        case .studyTime: "Build my plan"
        case .realityCheck: "Close the gap"
        case .plan: "Save my plan"
        default: "Continue"
        }
    }

    /// Runs after the change that adds or drops a page is laid out: a scroll position set before
    /// that is dropped.
    private func later(_ action: @escaping () -> Void) {
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            action()
        }
    }

    /// Starts writing the student's first patients, in the background: it outlives this screen.
    /// Not before the AI consent: writing a patient sends the student's picks to an AI provider.
    private func stockWard() {
        guard auth.account != nil, consented else { return }
        let focus = FocusSelection(stored: focusStored)
        Task { await app.stockWard(focus: focus) }
    }

    /// Makes (or finds) the account. One that already finished onboarding goes straight in;
    /// a new one goes on.
    private func signUp(with provider: SocialProvider) async {
        guard let account = await auth.continueWith(provider) else { return }
        if account.onboarded { auth.finishSignIn() } else { step(1) }
    }

    /// One page on or back; slides like a swipe, or switches instantly with Reduce Motion.
    private func step(_ by: Int) {
        guard let index = pages.firstIndex(of: page) else { return }
        // Back skips "Setting up": it only plays on the way forward.
        let to = by < 0 && pages.indices.contains(index + by) && pages[index + by] == .settingUp ? index + by - 1 : index + by
        guard pages.indices.contains(to) else { return }
        withAnimation(reduceMotion ? nil : Springs.slide) { visible = pages[to] }
    }

    #if DEBUG
    /// `-screen` names that open onboarding on a given page.
    private static let debugPages: [String: OnboardingPage] = [
        "onboarding": .schoolYear, "onboarding-year": .schoolYear, "onboarding-goal": .studyGoal,
        "onboarding-practice": .practice, "onboarding-blanked": .blanked, "onboarding-blanked-reply": .blankedReply,
        "onboarding-exam": .examDate, "onboarding-countdown": .countdown, "onboarding-study-time": .studyTime,
        "onboarding-pace": .pace, "onboarding-setting-up": .settingUp, "onboarding-plan": .plan,
        "onboarding-confidence": .confidence, "onboarding-reality": .realityCheck,
        "onboarding-account": .account, "onboarding-heard": .heardFrom,
        "onboarding-heart": .pledge, "onboarding-promised": .pledge,
    ]

    private func debugStart() {
        guard let screen = DebugLaunch.screen, let target = Self.debugPages[screen] else { return }
        // Answer every question before the target, so the carousel can reach it.
        if target.rawValue > OnboardingPage.schoolYear.rawValue, SchoolYear(stored: yearStored) == nil { yearStored = SchoolYear.ms3.rawValue }
        if target.rawValue > OnboardingPage.studyGoal.rawValue, goal == nil { goalStored = StudyGoal.step2CK.rawValue }
        if target.rawValue > OnboardingPage.examDate.rawValue, examStored.isEmpty, let month = ExamMonth.upcoming().dropFirst(2).first { examStored = month.stored }
        if target.rawValue > OnboardingPage.practice.rawValue { finished.insert(.practice) }
        if target.rawValue > OnboardingPage.confidence.rawValue, DiagnosisConfidence(stored: confidenceStored) == nil { confidenceStored = 6 }
        if target.rawValue > OnboardingPage.blanked.rawValue, blankStored.isEmpty { blankStored = BlankFrequency.often.rawValue }
        if target.rawValue > OnboardingPage.studyTime.rawValue, studyTimeStored.isEmpty { studyTimeStored = PracticeReminder.evening.rawValue }
        if target.rawValue > OnboardingPage.heardFrom.rawValue, heardStored.isEmpty { heardStored = HeardFrom.friend.rawValue }
        // Where-heard and the promise come after the account, so these screens start with the sample one.
        // Session restore can clear the sample right after launch, so also run as if onboarding
        // began signed in: no account page to gate the promise.
        if target.rawValue > OnboardingPage.account.rawValue { auth.debugUse(DebugLaunch.sampleAccount); startedSignedOut = false }
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

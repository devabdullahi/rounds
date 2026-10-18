import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Onboarding (each page, on arrival)
 *
 *    0ms   main card / avatar pops in, scale 0.85 → 1
 *   60ms+  the rest of the hero art follows, ~60ms apart
 *  150ms   (exam-ready page) "with Rounds" line draws (900ms)
 *  900ms   (exam-ready page) "With Rounds" label pops
 *
 * One carousel for every step, so swiping, Next and Back all slide the same way. The
 * background cross-fades between pages (mint, page colour for the focus picker, blush for
 * the promise). Pages past an unanswered step aren't added yet, so a swipe can't skip a
 * choice: the focus picker appears once a goal is picked, the account page once focus is set
 * (only when onboarding began signed out), the promise once there's an account.
 * After the promise the carousel locks. Reduce Motion: final states, instant page changes.
 * ───────────────────────────────────────────────────────── */

/// New-student onboarding: intro pages, study goal, focus, making the account and the promise,
/// as one carousel. Started from "First time?" it's signed out until the account page; started
/// by logging in with an account that never finished onboarding, that page is skipped.
struct OnboardingView: View {
    @Environment(AuthModel.self) private var auth
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(StudyGoal.storageKey) private var goalStored = ""
    @AppStorage(StudyFocus.storageKey) private var focusStored = ""

    /// The page in view. A paging scroll view, not a page-style TabView: TabView swaps pages
    /// instantly when Next sets the selection, so Next and a swipe would move differently.
    @State private var visible: OnboardingPage? = .patients
    @State private var seen: Set<OnboardingPage> = []
    @State private var pick = FocusSelection()
    @State private var mixChosen = false
    @State private var heart = HoldToCommit()
    @State private var holdingHeart = false
    /// Set on arrival: whether this run includes the account page.
    @State private var startedSignedOut = false

    private var page: OnboardingPage { visible ?? .patients }
    private var goalPicked: Bool { StudyGoal(stored: goalStored) != nil }
    private var focusReady: Bool { !pick.isMix || mixChosen }

    /// The pages a swipe may reach: everything up to the first unanswered choice.
    private var pages: [OnboardingPage] {
        OnboardingPage.allCases.filter { p in
            switch p {
            case .focus: goalPicked
            case .account: startedSignedOut && goalPicked && focusReady
            case .pledge: goalPicked && focusReady && auth.account != nil
            default: true
            }
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
        .onChange(of: page, initial: true) { _, p in seen.insert(p) }
        // The focus picker saves as it changes, so swiping on to the promise keeps the latest picks.
        .onChange(of: pick) { _, new in if focusReady { focusStored = new.stored } }
        .onChange(of: mixChosen) { _, _ in if focusReady { focusStored = pick.stored } }
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
        case .studyGoal: StudyGoalHero(shown: shown)
        case .focus, .account, .pledge: EmptyView()
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
        case .studyGoal:
            OnboardingNextButton(enabled: goalPicked) { step(1) }
        case .focus:
            OnboardingNextButton(title: "Continue", enabled: focusReady) { step(1) }
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
                OnboardingNextButton(title: "Get Started") { auth.finishOnboarding() }
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
    private func debugStart() {
        let laterPages = ["onboarding", "focus-system", "onboarding-account", "onboarding-heart", "onboarding-promised"]
        if laterPages.contains(DebugLaunch.screen ?? "") {
            if !goalPicked { goalStored = StudyGoal.step2CK.rawValue }
            pick = FocusSelection([.rotation(.internalMedicine), .rotation(.neurology)])
        }
        switch DebugLaunch.screen {
        case "onboarding-graded": visible = .graded
        case "onboarding-promise": visible = .promise
        case "onboarding-graph": visible = .examReady
        case "onboarding-goal": visible = .studyGoal
        case "onboarding", "focus-system": visible = .focus
        case "onboarding-account": visible = .account
        // The promise comes after the account, so these screens start with the sample one.
        case "onboarding-heart": auth.debugUse(DebugLaunch.sampleAccount); visible = .pledge
        case "onboarding-promised": auth.debugUse(DebugLaunch.sampleAccount); visible = .pledge; heart.complete()
        case "onboarding-to-goal":
            // Next three times, from the last intro page through the goal into the focus picker.
            visible = .examReady
            if !goalPicked { goalStored = StudyGoal.step2CK.rawValue }
            Task {
                for _ in 0..<2 { try? await Task.sleep(for: .seconds(1.5)); step(1) }
            }
        default: break
        }
    }
    #endif
}

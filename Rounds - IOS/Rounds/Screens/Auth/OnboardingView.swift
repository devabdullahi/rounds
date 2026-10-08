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
 * choice: the focus picker appears once a goal is picked, the promise once focus is set.
 * After the promise the carousel locks. Reduce Motion: final states, instant page changes.
 * ───────────────────────────────────────────────────────── */

/// New-student onboarding: intro pages, study goal, focus and the promise, as one carousel.
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

    private var page: OnboardingPage { visible ?? .patients }
    private var goalPicked: Bool { StudyGoal(stored: goalStored) != nil }
    private var focusReady: Bool { !pick.isMix || mixChosen }

    /// The pages a swipe may reach: everything up to the first unanswered choice.
    private var pages: [OnboardingPage] {
        OnboardingPage.allCases.filter { p in
            switch p {
            case .focus: goalPicked
            case .pledge: goalPicked && focusReady
            default: true
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingTopBar(total: OnboardingPage.allCases.count, current: page.rawValue + 1,
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
        #if DEBUG
        .onAppear { debugStart() }
        #endif
    }

    // MARK: Pages

    @ViewBuilder
    private func content(_ p: OnboardingPage) -> some View {
        switch p {
        case .focus:
            FocusPage(pick: $pick, mixChosen: $mixChosen)
        case .pledge:
            PledgePage(heart: $heart, isHolding: $holdingHeart)
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
        case .focus, .pledge: EmptyView()
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

    /// One page on or back; slides like a swipe, or switches instantly with Reduce Motion.
    private func step(_ by: Int) {
        guard let index = pages.firstIndex(of: page), pages.indices.contains(index + by) else { return }
        withAnimation(reduceMotion ? nil : Springs.slide) { visible = pages[index + by] }
    }

    #if DEBUG
    private func debugStart() {
        let laterPages = ["onboarding", "focus-system", "onboarding-heart", "onboarding-promised"]
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
        case "onboarding-heart": visible = .pledge
        case "onboarding-promised": visible = .pledge; heart.complete()
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

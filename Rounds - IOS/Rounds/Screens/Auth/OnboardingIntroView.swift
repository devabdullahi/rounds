import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Onboarding intro (each page, on arrival)
 *
 *    0ms   main card / avatar pops in, scale 0.85 → 1
 *   60ms+  the rest of the hero art follows, ~60ms apart
 *  150ms   (page 4) "with Rounds" line draws (900ms)
 *  900ms   (page 4) "With Rounds" label pops
 *
 * Pages swipe like a carousel; Next and Back move one page. Reduce Motion: final state.
 * The last page is the study-goal picker: Next stays off until a goal is picked, then
 * moves on to the focus screen.
 * ───────────────────────────────────────────────────────── */

struct OnboardingIntroView: View {
    @Environment(AuthRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The page in view. A paging scroll view, not a page-style TabView: TabView swaps pages
    /// instantly when Next sets the selection, so Next and a swipe would move differently.
    @State private var visible: IntroPage? = .patients
    @State private var seen: Set<IntroPage> = []
    @AppStorage(StudyGoal.storageKey) private var goalStored = ""

    private var page: IntroPage { visible ?? .patients }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingTopBar(total: OnboardingStep.total, current: page.rawValue + 1,
                             onBack: page == .patients ? nil : { step(-1) })
                .padding(.horizontal, 20)

            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(IntroPage.allCases, id: \.self) { p in
                        VStack(spacing: 14) {
                            hero(p).frame(maxHeight: 420)
                            OnboardingHeadline(text: p.headline)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .containerRelativeFrame(.horizontal)
                        .id(p)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $visible)

            OnboardingNextButton(enabled: page != .studyGoal || StudyGoal(stored: goalStored) != nil) {
                if page == .studyGoal { router.go(.focus) } else { step(1) }
            }
            .padding(.bottom, 12)
        }
        .background(HeroWash())
        .onChange(of: page, initial: true) { _, p in seen.insert(p) }
        #if DEBUG
        .onAppear {
            switch DebugLaunch.screen {
            case "onboarding-graded": visible = .graded
            case "onboarding-promise": visible = .promise
            case "onboarding-graph": visible = .examReady
            case "onboarding-goal": visible = .studyGoal
            case "onboarding-to-goal":
                // Next twice: into the last intro page, then the goal picker, to watch the slides.
                visible = .promise
                Task {
                    try? await Task.sleep(for: .seconds(2)); step(1)
                    try? await Task.sleep(for: .seconds(2)); step(1)
                }
            default: break
            }
        }
        #endif
    }

    @ViewBuilder
    private func hero(_ p: IntroPage) -> some View {
        let shown = seen.contains(p)
        switch p {
        case .patients: PatientsHero(shown: shown)
        case .graded: GradedHero(shown: shown)
        case .promise: PromiseHero(shown: shown)
        case .examReady: ExamReadyHero(shown: shown)
        case .studyGoal: StudyGoalHero(shown: shown)
        }
    }

    /// One page on or back; slides like a swipe, or switches instantly with Reduce Motion.
    private func step(_ by: Int) {
        guard let next = IntroPage(rawValue: page.rawValue + by) else { return }
        withAnimation(reduceMotion ? nil : Springs.slide) { visible = next }
    }
}

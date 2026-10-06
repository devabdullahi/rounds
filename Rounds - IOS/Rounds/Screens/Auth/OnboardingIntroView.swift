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
 * ───────────────────────────────────────────────────────── */

/// The four intro pages a new student sees right after creating an account.
enum IntroPage: Int, CaseIterable {
    case patients, graded, promise, examReady

    var headline: String {
        switch self {
        case .patients: "Patients Who\nTalk Back"
        case .graded: "Graded On\nEvery Move"
        case .promise: "Think Like\na Doctor"
        case .examReady: "Walk Into Your\nExam Ready"
        }
    }
}

struct OnboardingIntroView: View {
    @Environment(AuthRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = IntroPage.patients
    @State private var seen: Set<IntroPage> = []

    var body: some View {
        VStack(spacing: 0) {
            OnboardingTopBar(total: OnboardingStep.total, current: page.rawValue + 1,
                             onBack: page == .patients ? nil : { step(-1) })
                .padding(.horizontal, 20)

            TabView(selection: $page) {
                ForEach(IntroPage.allCases, id: \.self) { p in
                    VStack(spacing: 14) {
                        hero(p).frame(maxHeight: 420)
                        OnboardingHeadline(text: p.headline)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .tag(p)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            OnboardingNextButton {
                if page == .examReady { router.go(.studyGoal) } else { step(1) }
            }
            .padding(.bottom, 12)
        }
        .background(HeroWash())
        .onChange(of: page, initial: true) { _, p in seen.insert(p) }
        #if DEBUG
        .onAppear {
            switch DebugLaunch.screen {
            case "onboarding-graded": page = .graded
            case "onboarding-promise": page = .promise
            case "onboarding-graph": page = .examReady
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
        }
    }

    /// One page on or back; slides like a swipe, or switches instantly with Reduce Motion.
    private func step(_ by: Int) {
        guard let next = IntroPage(rawValue: page.rawValue + by) else { return }
        withAnimation(reduceMotion ? nil : Springs.slide) { page = next }
    }
}

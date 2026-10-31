import StoreKit
import SwiftUI

/// Signed out → account flow; signed in → the app. `AuthModel` owns the flag.
struct RootView: View {
    @AppStorage(AuthModel.signedInKey) private var signedIn = false
    @Environment(AppState.self) private var app
    @Environment(PaywallModel.self) private var paywall
    @Environment(AuthModel.self) private var auth
    @Environment(\.requestReview) private var requestReview
    @AppStorage(SchoolYear.storageKey) private var yearStored = ""
    @AppStorage(StudyGoal.storageKey) private var goalStored = ""
    /// The AI consent on this phone: nothing that reaches an AI provider runs before it.
    @AppStorage(AIConsent.storageKey) private var consentStored = AIConsent.withdrawn
    /// Fresh on every cold launch (process start), so the splash replays each time the app is reopened
    /// after being closed. Signed-out launches skip it: the welcome screen plays the same heart trace.
    @State private var showSplash = RootView.splashOnLaunch

    private static var splashOnLaunch: Bool {
        #if DEBUG
        if let screen = DebugLaunch.screen { return screen == "splash" }
        #endif
        return UserDefaults.standard.bool(forKey: AuthModel.signedInKey)
    }

    /// The student's badge, shown once right after buying.
    private var welcomeAboard: some View {
        WelcomeAboardView(fullName: auth.account?.name,
                          year: SchoolYear(stored: yearStored), goal: StudyGoal(stored: goalStored),
                          plan: paywall.activePlan) { paywall.welcomed() }
    }

    /// `-screen plan-checking` holds the spinner shown while the plan check hasn't answered.
    private static func debugPlanCheck(_ entitled: Bool?) -> Bool? {
        #if DEBUG
        if DebugLaunch.screen == "plan-checking" { return nil }
        #endif
        return entitled
    }

    var body: some View {
        ZStack {
            if signedIn {
                // Signed in, the app opens only with an active plan (or free cases left); until the
                // store answers, nothing shows. The AI consent was given by making the account.
                switch Self.debugPlanCheck(paywall.opensApp) {
                case true?: MainTabsView().transition(.opacity)
                case false?: GateView(model: paywall).transition(.opacity)
                // The plan check can take a moment (StoreKit, then our server): say so, never a blank.
                case nil: ProgressView()
                    .controlSize(.large)
                    .tint(Theme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.bg.ignoresSafeArea())
                    .accessibilityLabel("Checking your plan")
                }
            } else {
                AuthFlowView().transition(.opacity)
            }
            if showSplash {
                SplashView { withAnimation(SPLASH.exit) { showSplash = false } }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: signedIn)
        .animation(.easeInOut(duration: 0.35), value: paywall.opensApp)
        // Right after buying: the student's badge, once, before the app.
        .fullScreenCover(isPresented: Binding(get: { paywall.justBought && signedIn }, set: { if !$0 { paywall.welcomed() } })) {
            welcomeAboard
        }
        // Leaving a graded case may have used up the last free one (the third): check, so the paywall shows now.
        .onChange(of: app.casesFinished) { _, _ in
            guard paywall.isEntitled != true else { return }
            Task { await paywall.refresh() }
        }
        // The free cases are used up and the student asked for another patient: offer plans.
        .onChange(of: app.planNeeded) { _, needed in
            guard needed else { return }
            app.planNeeded = false
            if !paywall.offerPlans() { app.problem = PlanRequiredError().localizedDescription }
        }
        // After the first graded patient: Apple's rating sheet, a beat after landing on the ward so it
        // doesn't arrive mid-transition. Only Apple's own sheet, never a custom one or a reward.
        .task(id: app.ratingDue) {
            guard app.ratingDue else { return }
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            app.ratingAsked()
            requestReview()
        }
        .animation(.easeInOut(duration: 0.35), value: consentStored)
        // Signing out (or deleting the account) leaves nothing of that account behind for the next
        // one, including the consent: whoever signs in next agrees for themselves.
        .onChange(of: signedIn, initial: true) { _, now in
            // Signing in under the sign-up note is the agreement (SignUpTermsNote).
            guard !now else {
                if !AIConsent.isGiven(stored: consentStored) { consentStored = AIConsent.agreed }
                return
            }
            app.reset()
            consentStored = AIConsent.withdrawn
        }
        .background(Theme.bg.ignoresSafeArea())
        #if DEBUG
        .overlay { if DebugLaunch.isVoiceGlass { VoiceGlassDebugView() } }
        // `-screen purchased`: the welcome after buying, over whatever the launch shows.
        .overlay { if DebugLaunch.screen == "purchased" { welcomeAboard } }
        #endif
    }
}

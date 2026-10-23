import SwiftUI

/// Signed out → account flow; signed in → the app. `AuthModel` owns the flag.
struct RootView: View {
    @AppStorage(AuthModel.signedInKey) private var signedIn = false
    @Environment(AppState.self) private var app
    @Environment(PaywallModel.self) private var paywall
    @Environment(AuthModel.self) private var auth
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
                // Signed in, the app opens only with an active plan (or the free first case) and the AI
                // consent; until the store answers, nothing shows.
                switch Self.debugPlanCheck(paywall.opensApp) {
                case true? where AIConsent.isGiven(stored: consentStored): MainTabsView().transition(.opacity)
                case true?: AIConsentView().transition(.opacity)
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
        // Leaving a graded case may have used up the free one: check, so the paywall shows now.
        .onChange(of: app.casesFinished) { _, _ in
            guard paywall.isEntitled != true else { return }
            Task { await paywall.refresh() }
        }
        .animation(.easeInOut(duration: 0.35), value: consentStored)
        // Signing out (or deleting the account) leaves nothing of that account behind for the next
        // one, including the consent: whoever signs in next agrees for themselves.
        .onChange(of: signedIn) { _, now in
            guard !now else { return }
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

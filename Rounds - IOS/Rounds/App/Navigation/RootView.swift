import SwiftUI

/// Signed out → account flow; signed in → the app. `AuthModel` owns the flag.
struct RootView: View {
    @AppStorage(AuthModel.signedInKey) private var signedIn = false
    @Environment(AppState.self) private var app
    @Environment(PaywallModel.self) private var paywall
    /// Fresh on every cold launch (process start), so the splash replays each time the app is reopened
    /// after being closed. Signed-out launches skip it: the welcome screen plays the same heart trace.
    @State private var showSplash = RootView.splashOnLaunch

    private static var splashOnLaunch: Bool {
        #if DEBUG
        if let screen = DebugLaunch.screen { return screen == "splash" }
        #endif
        return UserDefaults.standard.bool(forKey: AuthModel.signedInKey)
    }

    var body: some View {
        ZStack {
            if signedIn {
                // Signed in, the app opens only with an active plan; until the store answers, nothing shows.
                switch paywall.isEntitled {
                case true?: MainTabsView().transition(.opacity)
                case false?: PaywallView(model: paywall).transition(.opacity)
                case nil: Theme.bg.ignoresSafeArea()
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
        .animation(.easeInOut(duration: 0.35), value: paywall.isEntitled)
        // Signing out (or deleting the account) leaves nothing of that account behind for the next one.
        .onChange(of: signedIn) { _, now in if !now { app.reset() } }
        .background(Theme.bg.ignoresSafeArea())
    }
}

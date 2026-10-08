import SwiftUI

/// Signed out → account flow; signed in → the app. Mock flag only until auth exists.
struct RootView: View {
    @AppStorage("signedIn") private var signedIn = false
    /// Fresh on every cold launch (process start), so the splash replays each time the app is reopened
    /// after being closed. Signed-out launches skip it: the welcome screen plays the same heart trace.
    @State private var showSplash = RootView.splashOnLaunch

    private static var splashOnLaunch: Bool {
        #if DEBUG
        if let screen = DebugLaunch.screen { return screen == "splash" }
        #endif
        return UserDefaults.standard.bool(forKey: "signedIn")
    }

    var body: some View {
        ZStack {
            if signedIn {
                MainTabsView().transition(.opacity)
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
        .background(Theme.bg.ignoresSafeArea())
    }
}

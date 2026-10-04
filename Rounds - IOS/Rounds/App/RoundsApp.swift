import SwiftUI

@main
struct RoundsApp: App {
    @State private var app = AppState()
    /// 0 = follow the system, 1 = light, 2 = dark.
    @AppStorage("appearance") private var appearance = 0

    init() {
        #if DEBUG
        DebugLaunch.prepareDefaults()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .preferredColorScheme(appearance == 1 ? .light : appearance == 2 ? .dark : nil)
                .tint(Theme.accent)
        }
    }
}

enum Tab: CaseIterable {
    case today, patients, cards, profile

    var title: String {
        switch self {
        case .today: "Today"
        case .patients: "Patients"
        case .cards: "Flashcards"
        case .profile: "Profile"
        }
    }

    var glyph: IconGlyph {
        switch self {
        case .today: .hospital
        case .patients: .patientChart
        case .cards: .cards
        case .profile: .user
        }
    }
}

/// Signed out → account flow; signed in → the app. Mock flag only until auth exists.
struct RootView: View {
    @AppStorage("signedIn") private var signedIn = false
    /// Fresh on every cold launch (process start), so the splash replays each time the app is reopened
    /// after being closed. First-time users skip it: First open already plays the same intro.
    @State private var showSplash = RootView.splashOnLaunch

    private static var splashOnLaunch: Bool {
        #if DEBUG
        if let screen = DebugLaunch.screen { return screen == "splash" }
        #endif
        return UserDefaults.standard.bool(forKey: "hasSeenFirstOpen")
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

struct MainTabsView: View {
    @Environment(AppState.self) private var app
    @State private var tab: Tab = .today
    @State private var debugExpanded: String?

    var body: some View {
        @Bindable var app = app
        // System tab bar: Liquid Glass with Apple's own selection morph on iOS 26+.
        TabView(selection: $tab) {
            HomeView(openProfile: { tab = .profile })
                .tabItem { Image(Tab.today.glyph.assetName).accessibilityLabel(Tab.today.title) }
                .tag(Tab.today)
            PatientsView(initialExpanded: debugExpanded)
                .tabItem { Image(Tab.patients.glyph.assetName).accessibilityLabel(Tab.patients.title) }
                .tag(Tab.patients)
            FlashcardsView()
                .tabItem { Image(Tab.cards.glyph.assetName).accessibilityLabel(Tab.cards.title) }
                .tag(Tab.cards)
            ProfileView()
                .tabItem { Image(Tab.profile.glyph.assetName).accessibilityLabel(Tab.profile.title) }
                .tag(Tab.profile)
        }
        .tint(Theme.accent)
        .onAppear {
            #if DEBUG
            DebugLaunch.apply(app: app, tab: &tab, expandedPatient: &debugExpanded)
            #endif
        }
        .fullScreenCover(item: $app.activeCase) { session in
            CaseFlowView(session: session)
                .environment(app)
        }
    }
}

extension CaseSession: Identifiable {
    var id: ObjectIdentifier { ObjectIdentifier(self) }
}

// MARK: - Case flow navigation

enum CaseStep: Hashable {
    case interview, workup, diagnosis, handoff, debrief
}

@Observable
final class CaseRouter {
    var path: [CaseStep] = []
    func go(_ step: CaseStep) { path.append(step) }
    func back() { if !path.isEmpty { path.removeLast() } }
    func restart() { path = [] }
}

struct CaseFlowView: View {
    @Environment(AppState.self) private var app
    let session: CaseSession
    @State private var router = CaseRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            BriefView(session: session)
                .navigationDestination(for: CaseStep.self) { step in
                    Group {
                        switch step {
                        case .interview: InterviewView(session: session)
                        case .workup: WorkupView(session: session)
                        case .diagnosis: DiagnosisView(session: session)
                        case .handoff: HandoffView(session: session)
                        case .debrief: DebriefView(session: session)
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
                .toolbar(.hidden, for: .navigationBar)
        }
        .environment(router)
        .onAppear {
            if !app.debugInitialPath.isEmpty {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { router.path = app.debugInitialPath }
                app.debugInitialPath = []
            }
        }
    }
}

// MARK: - Edge swipe back with the nav bar hidden

extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1 && !NavLock.isLocked
    }
}

/// Screens past a point of no return (submitted diagnosis) switch off edge-swipe back.
enum NavLock {
    nonisolated(unsafe) static var isLocked = false
}

extension View {
    func lockSwipeBack() -> some View {
        onAppear { NavLock.isLocked = true }
            .onDisappear { NavLock.isLocked = false }
    }
}

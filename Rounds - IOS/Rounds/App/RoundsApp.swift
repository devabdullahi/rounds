import AppIntents
import SwiftUI

@main
struct RoundsApp: App {
    @State private var app: AppState
    @State private var auth = AuthModel(service: SupabaseService.client.map { LiveAuthService(client: $0) })
    @State private var paywall: PaywallModel
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.defaultChoice
    @AppStorage(AuthModel.signedInKey) private var signedIn = false
    /// The exam picked in onboarding, passed to Superwall for audience targeting.
    @AppStorage(StudyGoal.storageKey) private var studyGoal = ""
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let app = AppState(cases: SupabaseService.client.map { LiveCaseService(client: $0) },
                           cards: SupabaseService.client.map { LiveCardService(client: $0) },
                           reminders: LocalReminderService())
        _app = State(initialValue: app)
        _paywall = State(initialValue: Self.paywallModel)
        SuperwallService.configure()
        // Siri and Shortcuts act on the same app state the screens show.
        AppDependencyManager.shared.add { app }
        #if DEBUG
        DebugLaunch.prepareDefaults()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(auth)
                .environment(paywall)
                .task {
                    #if DEBUG
                    // Debug screens other than the paywall open straight into the app.
                    if let screen = DebugLaunch.screen, !DebugLaunch.paywallScreens.contains(screen) { paywall.debugUnlock() }
                    #endif
                    await paywall.start()
                }
                .task {
                    await auth.restore()
                    #if DEBUG
                    if ["settings", "settings-siri", "settings-voice", "settings-about", "settings-subscription", "profile", "profile-edit"].contains(DebugLaunch.screen) { auth.debugUse(DebugLaunch.sampleAccount) }
                    #endif
                }
                // Superwall's paywall previews, Google's sheet returning, and email confirmation links
                // (rounds://auth-callback).
                .onOpenURL { url in
                    if SuperwallService.handle(url) { return }
                    Task { await auth.open(url) }
                }
                // A plan bought, cancelled or refunded elsewhere: check again whenever the app returns.
                .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await paywall.refresh() } } }
                // Superwall ties purchases to the signed-in account, and forgets it on sign-out.
                .onChange(of: auth.account?.id, initial: true) { _, id in
                    // Access belongs to the account: check again whenever a different one signs in.
                    Task { await paywall.accountChanged(signedIn: id != nil) }
                    SuperwallService.identify(id)
                    SuperwallService.setStudyGoal(studyGoal)
                }
                .onChange(of: studyGoal) { _, goal in SuperwallService.setStudyGoal(goal) }
                .environment(\.reference, .live)
                .preferredColorScheme(colorScheme)
                .tint(Theme.accent)
        }
    }

    /// The gate: the App Store plus the account check, or scripted ones on debug screens.
    private static var paywallModel: PaywallModel {
        #if DEBUG
        if DebugLaunch.screen == "paywall-taken" {
            return PaywallModel(store: MockSubscriptionStore(entitled: true),
                                accounts: MockAccountSubscriptionService(claim: AccountAccess(entitled: false, ownedBy: "j•••@gmail.com")),
                                verifiesAccount: true)
        }
        #endif
        return PaywallModel(store: subscriptionStore,
                            accounts: SupabaseService.client.map { LiveAccountSubscriptionService(client: $0) })
    }

    /// The App Store, or offline plans on the paywall debug screen.
    private static var subscriptionStore: any SubscriptionStore {
        #if DEBUG
        if ["paywall", "paywall-unavailable", "paywall-delete"].contains(DebugLaunch.screen) { return MockSubscriptionStore() }
        if DebugLaunch.screen == "settings-subscription" { return MockSubscriptionStore(entitled: true) }
        #endif
        return StoreKitSubscriptionStore()
    }

    /// Signed-out screens (welcome, sign up, onboarding) are designed for light mode; signed in,
    /// the student's choice, or nil to follow the system.
    private var colorScheme: ColorScheme? {
        // The paywall sits between onboarding and the app, so it keeps onboarding's light look.
        guard signedIn, paywall.isEntitled == true else { return .light }
        switch appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

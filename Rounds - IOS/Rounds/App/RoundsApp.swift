import AppIntents
import SwiftUI

@main
struct RoundsApp: App {
    @State private var app: AppState
    @State private var auth = AuthModel(service: SupabaseService.client.map { LiveAuthService(client: $0) })
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system
    @AppStorage(AuthModel.signedInKey) private var signedIn = false

    init() {
        let app = AppState(cases: SupabaseService.client.map { LiveCaseService(client: $0) },
                           cards: SupabaseService.client.map { LiveCardService(client: $0) },
                           reminders: LocalReminderService())
        _app = State(initialValue: app)
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
                .task {
                    await auth.restore()
                    #if DEBUG
                    if ["settings", "settings-siri", "settings-voice", "profile", "profile-edit"].contains(DebugLaunch.screen) { auth.debugUse(DebugLaunch.sampleAccount) }
                    #endif
                }
                // Google's sheet returning, and email confirmation links (rounds://auth-callback).
                .onOpenURL { url in Task { await auth.open(url) } }
                .environment(\.reference, .live)
                .preferredColorScheme(colorScheme)
                .tint(Theme.accent)
        }
    }

    /// Signed-out screens (welcome, sign up, onboarding) are designed for light mode; signed in,
    /// the student's choice, or nil to follow the system.
    private var colorScheme: ColorScheme? {
        guard signedIn else { return .light }
        switch appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

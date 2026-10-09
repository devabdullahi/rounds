import SwiftUI

@main
struct RoundsApp: App {
    @State private var app = AppState(cases: SupabaseService.client.map { LiveCaseService(client: $0) },
                                      cards: SupabaseService.client.map { LiveCardService(client: $0) },
                                      reminders: LocalReminderService())
    @State private var auth = AuthModel(service: SupabaseService.client.map { LiveAuthService(client: $0) })
    /// 0 = follow the system, 1 = light, 2 = dark.
    @AppStorage("appearance") private var appearance = 0
    @AppStorage("signedIn") private var signedIn = false

    init() {
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
                    if ["settings", "profile", "profile-edit"].contains(DebugLaunch.screen) { auth.debugUse(DebugLaunch.sampleAccount) }
                    #endif
                }
                // Google's sheet returning, and email confirmation links (rounds://auth-callback).
                .onOpenURL { url in Task { await auth.open(url) } }
                .environment(\.reference, .live)
                // Signed-out screens (welcome, sign up, onboarding) are designed for light mode.
                .preferredColorScheme(!signedIn || appearance == 1 ? .light : appearance == 2 ? .dark : nil)
                .tint(Theme.accent)
        }
    }
}

extension CaseSession: Identifiable {
    nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }
}

// MARK: - Case flow navigation

// MARK: - Edge swipe back with the nav bar hidden

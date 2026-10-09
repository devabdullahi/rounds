import SwiftUI

struct MainTabsView: View {
    @Environment(AppState.self) private var app
    @Environment(AuthModel.self) private var auth
    @State private var tab: Tab = .today
    @State private var debugExpanded: String?

    var body: some View {
        @Bindable var app = app
        // System tab bar: Liquid Glass with Apple's own selection morph on iOS 26+.
        TabView(selection: $tab) {
            HomeView()
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
        .task { await app.refresh() }
        #if DEBUG
        // Development builds: a guest (signed out) sees every badge earned and a maxed streak.
        .onChange(of: auth.account == nil, initial: true) { _, guest in app.guestShowcase = guest }
        #endif
        .alert("Something went wrong", isPresented: Binding(get: { app.problem != nil }, set: { if !$0 { app.problem = nil } })) {
            Button("Try again") { Task { await app.refresh() } }
            Button("OK", role: .cancel) {}
        } message: {
            Text(app.problem ?? "")
        }
        // A graded case ends on the ward, where the student picks their next patient.
        .onChange(of: app.returnToPatients) { _, go in
            guard go else { return }
            tab = .patients
            app.returnToPatients = false
        }
        .onChange(of: app.reviewMistakesRequested) { _, go in
            if go { tab = .cards }
        }
        .onChange(of: app.showTodayRequested, initial: true) { _, go in
            guard go else { return }
            tab = .today
            app.showTodayRequested = false
        }
        // The streak, big and centred, over the tabs.
        .overlay {
            if app.showingStreak {
                StreakSpotlight(
                    days: app.streak,
                    heat: Streak.heat(app.streak),
                    tint: app.streak == 0 ? Theme.streakCold : Theme.streakWeeks[Streak.weekColorIndex(app.streak)],
                    caption: app.streakTimeLeft.map(Streak.timeLeftText) ?? "Finish a case to start a streak",
                    onClose: { withAnimation(.easeOut(duration: 0.2)) { app.showingStreak = false } }
                )
                .transition(.opacity)
            }
        }
        // A newly earned badge gets its moment over everything, once, outside a case.
        .overlay {
            if let unlock = app.pendingUnlocks.first, app.activeCase == nil {
                BadgeUnlockView(status: unlock) { withAnimation(.easeOut(duration: 0.25)) { app.celebrated(unlock) } }
                    .id(unlock.id)
                    .transition(.opacity)
            }
        }
        .fullScreenCover(item: $app.activeCase) { session in
            CaseFlowView(session: session)
                .environment(app)
        }
    }
}

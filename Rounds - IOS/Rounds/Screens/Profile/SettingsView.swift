import StoreKit
import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Settings
 *
 *   voice off      dependent rows dim to 40% (they stay in place:
 *                  greyed, not removed, so nothing jumps)
 *   appearance     whole app recolors through the system transition
 * ───────────────────────────────────────────────────────── */

private enum SETTINGS {
    static let dependentDim = 0.4     // opacity of rows that need voice mode
    static let dimAnimation = Springs.slide
    static let voiceSection = "voice"  // scroll target for the settings-voice debug screen
}

/// Settings: account facts, study focus, and device preferences. Preferences are stored on this
/// device (`Preferences`, `Appearance`, `TimeLimit`), and the screens and models that use them read
/// the same keys.
struct SettingsView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    // Shared with the door note so both show the same default.
    @AppStorage(TimeLimit.storageKey) private var timeLimit = TimeLimit.defaultMinutes
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system

    @AppStorage(Preferences.examByDefaultKey) private var examByDefault = Preferences.examByDefaultDefault
    @AppStorage(Preferences.voiceModeKey) private var voiceMode = Preferences.voiceModeDefault
    @AppStorage(Preferences.autoSendKey) private var autoSend = Preferences.autoSendDefault
    @AppStorage(Preferences.voiceSpeedKey) private var voiceSpeed = Preferences.voiceSpeedDefault
    /// Whether iOS has a non-robotic voice installed; checked once, when Settings opens.
    @State private var hasNaturalVoice = PatientVoice.hasNaturalVoice()
    @AppStorage(Preferences.showRevealsKey) private var showReveals = Preferences.showRevealsDefault
    @AppStorage(Preferences.showCoverageKey) private var showCoverage = Preferences.showCoverageDefault
    @AppStorage(Preferences.hapticsKey) private var haptics = Preferences.hapticsDefault
    @AppStorage(Preferences.streakAlertsKey) private var streakAlerts = Preferences.streakAlertsDefault
    @State private var confirmSignOut = false
    @Environment(AuthModel.self) private var auth
    @Environment(PaywallModel.self) private var paywall
    /// Apple's own subscription sheet, for a plan bought in the app.
    @State private var managingAppStorePlan = false
    @State private var confirmDelete = false
    @AppStorage(StudyFocus.storageKey) private var focusStored = ""
    @State private var editingFocus = false
    @State private var editingProfile = false
    @State private var showingCredits = false
    @State private var showingSiri = false

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Settings") {
                IconButton(glyph: .chevronLeft, label: "Back") { dismiss() }
            } trailing: { EmptyView() }

            ScrollViewReader { scroller in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Profile (photo, name, specialty) is the student's to change; email and provider come from how
                    // they signed in, so they read as plain facts (no chevron, not tappable).
                    section("Account") {
                        if let account = auth.account {
                            navRow(.user, "Profile", value: account.name ?? "Add your name") { editingProfile = true }
                            Hairline()
                        }
                        infoRow(.mail, "Email", value: auth.account?.email ?? "Guest session")
                        Hairline()
                        infoRow(.keyRound, "Signed in with", value: auth.account?.providerLabel ?? "Not signed in")
                    }

                    // Where the plan was bought decides where it's managed: Apple's sheet, or Stripe's portal in Safari.
                    section("Subscription") {
                        if let plan = paywall.activePlan {
                            navRow(.crown, "Manage subscription", detail: "\(plan.summary()) · \(plan.manageHint)") { manage(plan) }
                        } else {
                            infoRow(.crown, "Subscription", value: "No active plan")
                        }
                    }

                    section("Practice") {
                        navRow(.target, "Study focus", value: focusSummary) { editingFocus = true }
                    }

                    section("Appearance") {
                        Segmented(options: Appearance.allCases.map { ($0, $0.title) }, selection: $appearance)
                            .padding(12)
                    }

                    section("Cases") {
                        VStack(alignment: .leading, spacing: 10) {
                            rowLabel(.timer, "Default time limit")
                            Segmented(options: TimeLimit.options, selection: $timeLimit)
                        }
                        .padding(16)
                        Hairline()
                        toggleRow(.bookOpen, "Start in Exam mode", detail: "No hints until the debrief", isOn: $examByDefault)
                    }

                    section("Talking to patients") {
                        toggleRow(.mic, "Voice mode", detail: "Speak your questions out loud", isOn: $voiceMode)
                        Hairline()
                        toggleRow(.audioLines, "Send after a pause", detail: "When off, tap the orb to send", isOn: $autoSend)
                            .disabled(!voiceMode)
                            .opacity(voiceMode ? 1 : SETTINGS.dependentDim)
                        Hairline()
                        VStack(alignment: .leading, spacing: 10) {
                            rowLabel(.gauge, "Patient voice speed")
                            HStack(spacing: 12) {
                                Text("Slower").font(.system(size: 13)).foregroundStyle(Theme.muted)
                                Slider(value: $voiceSpeed, in: 0...1)
                                    .tint(Theme.accent)
                                    .accessibilityLabel("Patient voice speed")
                                Text("Faster").font(.system(size: 13)).foregroundStyle(Theme.muted)
                            }
                            if !hasNaturalVoice {
                                Text("For a natural patient voice, download an Enhanced or Premium English voice in iOS Settings › Accessibility › Spoken Content › Voices.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(16)
                        .disabled(!voiceMode)
                        .opacity(voiceMode ? 1 : SETTINGS.dependentDim)
                    }
                    .animation(SETTINGS.dimAnimation, value: voiceMode)
                    .id(SETTINGS.voiceSection)

                    section("Feedback") {
                        toggleRow(.eye, "Show revealed findings", detail: "Chips in the interview as you uncover facts", isOn: $showReveals)
                        Hairline()
                        toggleRow(.clipboardList, "Key history meter", isOn: $showCoverage)
                        Hairline()
                        toggleRow(.vibrate, "Haptics", isOn: $haptics)
                    }

                    section("Reminders") {
                        toggleRow(.flame, "Streak alerts", detail: "A nudge before your streak ends", isOn: $streakAlerts)
                    }

                    section("Siri & Shortcuts") {
                        navRow(.mic, "Siri commands") { showingSiri = true }
                    }

                    section("About") {
                        linkRow(.messageSquare, "Send feedback", AppLinks.feedback)
                        linkRow(.shield, "Privacy", AppLinks.privacyPolicy)
                        linkRow(.fileText, "Terms", AppLinks.terms)
                        navRow(.info, "Acknowledgements") { showingCredits = true }
                    }

                    VStack(spacing: 10) {
                        Button { confirmSignOut = true } label: {
                            HStack(spacing: 8) {
                                AppIcon(.logOut, size: 18)
                                Text("Sign out")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .glassCapsule(tint: Theme.wrong)   // true red fill in both modes
                        }
                        .buttonStyle(PressDownStyle())
                        .disabled(auth.busy != nil)

                        // Apple requires in-app deletion for apps with accounts.
                        Button("Delete account", role: .destructive) { confirmDelete = true }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.warnText)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .disabled(auth.busy != nil)

                        Text("Rounds \(AppVersion.display)\nFor training only. Not for clinical use.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.faint)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            #if DEBUG
            .onAppear { if DebugLaunch.screen == "settings-voice" { scroller.scrollTo(SETTINGS.voiceSection, anchor: .top) } }
            #endif
            }
        }
        .background(Theme.bg)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $editingFocus) { FocusSheet(counts: app.topicCounts) }
        .confirmationDialog("Sign out of Rounds?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { Task { await auth.signOut() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your streak and casebook stay saved to your account.")
        }
        .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete account and data", role: .destructive) { Task { await auth.deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your patients, grades, flashcards and badges are deleted for good. This can't be undone.")
        }
        .sheet(isPresented: $editingProfile) { EditProfileView() }
        .sheet(isPresented: $showingCredits) { AcknowledgementsView() }
        .sheet(isPresented: $showingSiri) { SiriCommandsView() }
        .manageSubscriptionsSheet(isPresented: $managingAppStorePlan)
        // Picks up a cancellation or plan change made in Apple's sheet or Stripe's portal.
        .task { await paywall.refresh() }
        #if DEBUG
        .onAppear { if DebugLaunch.screen == "settings-siri" { showingSiri = true } }
        #endif
        .problemAlert(Binding(get: { auth.problem }, set: { auth.problem = $0 }))
        // Turning streak alerts off clears a pending reminder now, not after the next case.
        .onChange(of: streakAlerts) { Task { await app.updateReminder() } }
    }

    // MARK: Pieces

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(title)
            VStack(spacing: 0, content: content).listSurface()
        }
    }

    private func iconTile(_ glyph: IconGlyph) -> some View {
        AppIcon(glyph, size: 18)
            .foregroundStyle(Theme.accent)
            .frame(width: 32, height: 32)
            .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func manage(_ plan: ActivePlan) {
        switch plan.source {
        case .appStore: managingAppStorePlan = true
        case .web: Task { if let url = await paywall.webPortalURL() { openURL(url) } }
        }
    }

    private func rowLabel(_ glyph: IconGlyph, _ title: String) -> some View {
        HStack(spacing: 12) {
            iconTile(glyph)
            Text(title).font(.system(size: 16))
        }
    }

    private func toggleRow(_ glyph: IconGlyph, _ title: String, detail: String? = nil, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                iconTile(glyph)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 16))
                    if let detail {
                        Text(detail).font(.system(size: 13)).foregroundStyle(Theme.muted)
                    }
                }
            }
        }
        .tint(Theme.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 56)
    }

    /// A row that opens `url`, followed by a hairline; nothing at all until the link exists.
    @ViewBuilder
    private func linkRow(_ glyph: IconGlyph, _ title: String, _ url: URL?) -> some View {
        if let url {
            navRow(glyph, title) { openURL(url) }
            Hairline()
        }
    }

    /// Short enough for a settings row: one name, or a count once there are several.
    private var focusSummary: String {
        let focus = FocusSelection(stored: focusStored)
        return focus.items.count > 1 ? "\(focus.items.count) picked" : focus.label
    }

    /// A read-only fact: same look as a row, without the chevron or a tap target.
    private func infoRow(_ glyph: IconGlyph, _ title: String, value: String) -> some View {
        HStack(spacing: 12) {
            iconTile(glyph)
            Text(title).font(.system(size: 16))
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .accessibilityElement(children: .combine)
    }

    private func navRow(_ glyph: IconGlyph, _ title: String, value: String? = nil, detail: String? = nil, action: @escaping () -> Void = {}) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                iconTile(glyph)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 16))
                    if let detail {
                        Text(detail).font(.system(size: 13)).foregroundStyle(Theme.muted)
                    }
                }
                Spacer()
                if let value {
                    Text(value).font(.system(size: 15)).foregroundStyle(Theme.muted)
                }
                AppIcon(.chevronRight, size: 18).foregroundStyle(Theme.faint)
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 16)
            .padding(.vertical, detail == nil ? 0 : 10)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}

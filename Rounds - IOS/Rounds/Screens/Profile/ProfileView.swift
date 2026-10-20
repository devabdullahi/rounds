import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var app
    @Environment(AuthModel.self) private var auth

    // MOCK (disabled): sample weak spots, replaced by the graded-case breakdown (Performance).
    // private let weakSpots: [(String, Double, Bool)] = [
    //     ("Social history", 0.42, true), ("Red-flag questions", 0.55, false),
    //     ("Examination", 0.64, false), ("Test selection", 0.78, false),
    // ]

    /// Pages pushed from Profile.
    enum Route: Hashable { case settings, weakSpots, badges }

    @State private var path: [Route] = []
    @State private var editingProfile = false

    var body: some View {
        NavigationStack(path: $path) {
            content
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .settings: SettingsView()
                    case .weakSpots: WeakSpotsView()
                    case .badges: BadgesView()
                    }
                }
                .sheet(isPresented: $editingProfile) { EditProfileView() }
        }
        #if DEBUG
        .onAppear {
            switch DebugLaunch.screen {
            case "settings", "settings-siri", "settings-voice", "settings-about", "settings-subscription": path = [.settings]
            case "profile-weakspots": path = [.weakSpots]
            case "profile-badges": path = [.badges]
            case "profile-edit": editingProfile = true
            default: break
            }
        }
        #endif
    }

    private var content: some View {
        ScrimScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenTitle(title: "Profile") {
                    Button { path.append(.settings) } label: {
                        AppIcon(.settings, size: 20).foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .glassCircle(tint: Theme.accent)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Settings")
                }

                identityCard

                HStack(alignment: .top, spacing: 10) {
                    statTile("\(app.patientsSeen)", "Patients seen")
                    statTile(app.rightDiagnosisText, "Correct diagnosis")
                    statTile("\(app.bestStreak)", "Best streak")
                }
                .fixedSize(horizontal: false, vertical: true)

                weakSpotsCard

                badgesCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .background(Theme.bg)
    }

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                // Only the identity (photo, name, specialty) opens the editor, not the rating beside it.
                // Guests have no account to edit.
                Button { editingProfile = true } label: {
                    HStack(spacing: 14) {
                        Avatar(initials: auth.account?.initials ?? "G", size: 60, fg: Theme.accentInk, bg: Theme.accent,
                               imageURL: auth.account?.avatarURL)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(auth.account?.name ?? auth.account?.email ?? "Guest")
                                    .font(.system(size: 20, weight: .bold)).lineLimit(1)
                                if auth.account != nil {
                                    AppIcon(.pencil, size: 14).foregroundStyle(Theme.faint)
                                }
                            }
                            subtitle
                        }
                    }
                    .foregroundStyle(Theme.text)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .disabled(auth.account == nil)
                .accessibilityHint(auth.account == nil ? "" : "Edit your name, photo and specialty")
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(app.rating.formatted()).font(.score(22)).contentTransition(.numericText())
                    Text(app.tier.label).font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                ProgressBar(value: app.tierProgress)
                Text(app.tier.toNextLabel(app.rating))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }
        }
        .card(radius: 20)
    }

    /// Their specialty, or a prompt to add one; guests see what kind of account they're on.
    @ViewBuilder private var subtitle: some View {
        if let account = auth.account {
            Text(account.specialty?.label ?? "Add your specialty")
                .font(.system(size: 15))
                .foregroundStyle(account.specialty == nil ? Theme.accent : Theme.muted)
                .lineLimit(1)
        } else {
            Text("Practice account on this device")
                .font(.system(size: 15)).foregroundStyle(Theme.muted).lineLimit(2)
        }
    }

    private func statTile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.mono(22))
            Text(label).font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }
        .card(padding: 14, fillHeight: true)
    }

    /// The four categories losing the most points over the last 30 days; the whole card opens
    /// the full breakdown with its time filter.
    private var weakSpotsCard: some View {
        let result = Performance.stats(app.graded, in: .month)
        return Button { path.append(.weakSpots) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Where you lose points").font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Text("Last 30 days").font(.system(size: 13)).foregroundStyle(Theme.muted)
                    AppIcon(.chevronRight, size: 14).foregroundStyle(Theme.faint)
                }
                if result.cases == 0 {
                    Text("Finish a case to see where your points go.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.muted)
                } else {
                    VStack(spacing: 9) {
                        ForEach(Array(result.stats.prefix(4).enumerated()), id: \.element.id) { i, stat in
                            let weakest = i == 0 && stat.lost > 0
                            HStack(spacing: 10) {
                                Text(stat.category.label)
                                    .font(.system(size: 14, weight: weakest ? .semibold : .regular))
                                    .foregroundStyle(weakest ? Theme.warnText : Theme.text)
                                    .frame(width: 128, alignment: .leading)
                                ProgressBar(value: stat.share, color: weakest ? Theme.warn : Theme.faint)
                                Text("\(Int((stat.share * 100).rounded()))%")
                                    .font(.mono(14, weight: .medium))
                                    .frame(width: 40, alignment: .trailing)
                            }
                        }
                    }
                }
            }
            .foregroundStyle(Theme.text)
            .card()
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint("Shows every category, with a time filter")
    }

    /// Six badges and the unlocked count; opens the full list. Shows the latest earned ones, then
    /// the locked ones closest to unlocking.
    private var badgesCard: some View {
        let statuses = app.badgeStatuses
        let unlocked = statuses.filter(\.unlocked)
        let earned = Array(unlocked.sorted { ($0.earnedAt ?? .distantPast) < ($1.earnedAt ?? .distantPast) }.suffix(3))
        let close = BadgeCatalog.nearest(statuses, limit: 6 - earned.count)
        // A new student is close to almost nothing, so the easiest locked cards fill the row.
        let easiest = statuses.filter { s in !s.unlocked && !s.hidden && !close.contains { $0.badge.id == s.badge.id } }
            .sorted { $0.badge.rarity < $1.badge.rarity }
        let next = close + easiest.prefix(6 - earned.count - close.count)
        return Button { path.append(.badges) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text("Badges").font(.system(size: 13)).foregroundStyle(Theme.muted)
                    Spacer(minLength: 4)
                    Text("\(unlocked.count)/\(statuses.count)").font(.mono(12, weight: .medium)).foregroundStyle(Theme.muted)
                }
                HStack(spacing: 6) {
                    ForEach(earned + next) { status in
                        BadgeMedallion(status: status, size: 40).frame(maxWidth: .infinity)
                    }
                }
            }
            .foregroundStyle(Theme.text)
            .card(padding: 14, fillHeight: true)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Badges, \(unlocked.count) of \(statuses.count) unlocked")
        .accessibilityHint("Shows every badge")
    }
}

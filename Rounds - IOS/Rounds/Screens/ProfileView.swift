import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var app

    private let weakSpots: [(String, Double, Bool)] = [
        ("Social history", 0.42, true),
        ("Red-flag questions", 0.55, false),
        ("Examination", 0.64, false),
        ("Test selection", 0.78, false),
    ]

    @State private var showSettings = false
    @State private var showInventoryHelp = false

    var body: some View {
        NavigationStack {
            content
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $showSettings) { SettingsView() }
                .sheet(isPresented: $showInventoryHelp) { inventoryHelp }
        }
        #if DEBUG
        .onAppear { if DebugLaunch.screen == "settings" { showSettings = true } }
        #endif
    }

    private var content: some View {
        ScrimScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenTitle(title: "Profile") {
                    Button { showSettings = true } label: {
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
                    statTile("\(Int(app.rightDiagnosisRate * 100))%", "Correct diagnosis")
                    statTile("\(app.bestStreak)", "Best streak")
                }
                .fixedSize(horizontal: false, vertical: true)

                weakSpotsCard

                HStack(alignment: .top, spacing: 10) {
                    Button { showInventoryHelp = true } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("Inventory").font(.system(size: 13)).foregroundStyle(Theme.muted)
                                AppIcon(.info, size: 13).foregroundStyle(Theme.faint)
                            }
                            Text("1 Consult").font(.system(size: 15, weight: .semibold))
                            Text("2 Streak freezes").font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(Theme.text)
                        .card(padding: 14, fillHeight: true)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityHint("Explains consults and streak freezes")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Badges").font(.system(size: 13)).foregroundStyle(Theme.muted)
                        HStack(spacing: 6) {
                            badge("Bronze", tint: Theme.text, earned: true)
                            badge("Silver", tint: Theme.accent, earned: true)
                            badge("Gold", tint: Theme.faint, earned: false)
                        }
                    }
                    .card(padding: 14, fillHeight: true)
                }
                .fixedSize(horizontal: false, vertical: true)
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
                Avatar(initials: "AK", size: 60, fg: Theme.accentInk, bg: Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(SampleUser.name).font(.system(size: 20, weight: .bold))
                    Text(SampleUser.training).font(.system(size: 15)).foregroundStyle(Theme.muted).lineLimit(1).truncationMode(.tail)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(app.rating.formatted()).font(.score(22)).contentTransition(.numericText())
                    Text("Silver tier").font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
            }
            VStack(spacing: 4) {
                ProgressBar(value: app.tierProgress)
                HStack {
                    Text("\(app.toNextTier) to Gold")
                    Spacer()
                    Text("Season ends Dec 1")
                }
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
            }
        }
        .card(radius: 20)
    }

    private func statTile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.mono(22))
            Text(label).font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }
        .card(padding: 14, fillHeight: true)
    }

    private var weakSpotsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Where you lose points").font(.system(size: 17, weight: .semibold))
                Spacer()
                Text("Last 30 cases").font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
            VStack(spacing: 9) {
                ForEach(weakSpots, id: \.0) { name, value, weakest in
                    HStack(spacing: 10) {
                        Text(name)
                            .font(.system(size: 14, weight: weakest ? .semibold : .regular))
                            .foregroundStyle(weakest ? Theme.warnText : Theme.text)
                            .frame(width: 128, alignment: .leading)
                        ProgressBar(value: value, color: weakest ? Theme.warn : Theme.faint)
                        Text("\(Int(value * 100))%").font(.mono(14, weight: .medium)).frame(width: 40, alignment: .trailing)
                    }
                }
            }
            Button("Practice 5 social history cases") { app.startCase() }
                .buttonStyle(SoftButtonStyle(height: 44, fontSize: 16))
        }
        .card()
    }

    private func badge(_ name: String, tint: Color, earned: Bool) -> some View {
        VStack(spacing: 4) {
            AppIcon(.award, size: 18)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(earned ? 0.14 : 0.08), in: Circle())
            Text(name)
                .font(.system(size: 11, weight: earned ? .semibold : .regular))
                .foregroundStyle(earned ? Theme.text : Theme.faint)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(earned ? "\(name) tier badge, earned" : "\(name) tier badge, locked")
    }

    private var inventoryHelp: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Inventory").font(.system(size: 22, weight: .bold))
            helpRow(.messageSquare, "Consult", "Once per case, ask Dr. Okafor for a nudge. Using one caps that case at 90. You earn one every 3 days of streak.")
            helpRow(.flame, "Streak freeze", "Covers a missed day so your streak survives. Used automatically. Earned at 7- and 30-day streaks.")
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface.ignoresSafeArea())
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }

    private func helpRow(_ glyph: IconGlyph, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            AppIcon(glyph, size: 18)
                .foregroundStyle(Theme.accent)
                .frame(width: 32, height: 32)
                .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .semibold))
                Text(body).font(.system(size: 14)).foregroundStyle(Theme.muted).lineSpacing(2)
            }
        }
    }
}

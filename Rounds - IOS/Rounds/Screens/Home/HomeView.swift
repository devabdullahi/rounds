import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Home
 *
 * Read top-to-bottom. Each `at` value is ms after first appear.
 *
 *    0ms   header fades in
 *  150ms   patient deck rises, y 16 → 0
 *  450ms   top card's vitals tick in (staggered 80ms)
 *  750ms   patient quote fades up
 *  900ms   "Take the patient" button settles
 *
 * Swipe and button choreography lives in PatientDeck.swift.
 *
 * Plays once per launch; later visits render the final state.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let header    = 0.00   // header fades in
    static let card      = 0.15   // patient deck rises
    static let vitals    = 0.45   // vitals tick in
    static let quote     = 0.75   // quote fades up
    static let cta       = 0.90   // primary button settles
}

private enum CARD {
    static let offsetY: CGFloat = 16          // px the card rises from
    static let spring = Springs.card
}

/// The intro plays once per launch: later visits to Home render the final state.
private enum INTRO {
    @MainActor static var hasPlayed = false
}

struct HomeView: View {
    @Environment(AppState.self) private var app

    @State private var stage = INTRO.hasPlayed ? 4 : -1
    @State private var editingFocus = false
    @AppStorage(StudyFocus.storageKey) private var focusStored = ""
    @AppStorage(CareSetting.storageKey) private var settingStored = ""
    @AppStorage(DailyGoal.storageKey) private var dailyGoalStored = DailyGoal.default.rawValue
    private var focus: FocusSelection { FocusSelection(stored: focusStored) }

    var body: some View {
        ScrimScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                    .opacity(stage >= 0 ? 1 : 0)

                PatientDeck(stage: stage)
                    .opacity(stage >= 1 ? 1 : 0)
                    .offset(y: stage >= 1 ? 0 : CARD.offsetY)
                    .animation(CARD.spring, value: stage)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [Theme.bg.opacity(0), Theme.bg], startPoint: .top, endPoint: .bottom)
                .frame(height: 28)
                .allowsHitTesting(false)
        }
        .background {
            GlowBackdrop()   // Metal shader paints the background colour plus the glows
        }
        .task { await play() }
        // Write this focus's first patients ahead, so tapping a patient doesn't wait for one.
        .task(id: focusStored + "@" + settingStored) { await app.prepareAhead(focus: focus) }
        .sheet(isPresented: $editingFocus) { FocusSheet(counts: app.topicCounts) }
        #if DEBUG
        .onAppear { if DebugLaunch.screen == "focus-sheet" { editingFocus = true } }
        #endif
    }

    private func play() async {
        guard !INTRO.hasPlayed else { return }
        INTRO.hasPlayed = true
        let marks = [TIMING.header, TIMING.card, TIMING.vitals, TIMING.quote, TIMING.cta]
        var elapsed = 0.0
        for (i, at) in marks.enumerated() {
            try? await Task.sleep(for: .seconds(at - elapsed))
            elapsed = at
            withAnimation(.easeOut(duration: 0.3)) { stage = i }
        }
    }

    // MARK: Sections

    @AppStorage(Appearance.storageKey) private var appearance = Appearance.defaultChoice

    /// An explicit Light/Dark choice sets the shift; System follows the clock (07:00–18:59 is day).
    private var shiftTitle: String {
        switch appearance {
        case .light: return "Day shift"
        case .dark: return "Night shift"
        case .system:
            let hour = Calendar.current.component(.hour, from: .now)
            return (7..<19).contains(hour) ? "Day shift" : "Night shift"
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Brand row: the app is always named, without spending the headline on it.
            HStack {
                HStack(spacing: 8) {
                    AppIcon(.brandMark, size: 22).foregroundStyle(Theme.accent)
                    Text("Rounds").font(.system(size: 17, weight: .bold)).tracking(-0.2)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Rounds")
                Spacer()
                Button { withAnimation(.easeOut(duration: 0.25)) { app.showingStreak = true } } label: {
                    HStack(spacing: 6) {
                        // No streak: cold. Then the flame lights small and grows a little each day.
                        if app.streak == 0 {
                            AppIcon(.snowflake, size: 16)
                        } else {
                            StreakFlame(size: 16, color: .white, heat: Streak.heat(app.streak))
                        }
                        Text("\(app.streak)").font(.mono(15))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    // Cold at zero, then a new colour every 7 days of streak.
                    .glassCapsule(tint: Theme.streakTint(days: app.streak))
                    .animation(.easeInOut(duration: 0.4), value: Streak.weekColorIndex(app.streak))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("\(app.streak) day streak")
                .accessibilityHint("Shows your streak")
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(shiftTitle)
                        .font(.system(size: 34, weight: .bold))
                        .tracking(-0.5)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 8)
                    dailyCount
                }
                // An empty focus says so beside the chip, on the same line, so the deck doesn't move.
                HStack(spacing: 10) {
                    focusChip
                    if !focus.isMix, focus.items.allSatisfy({ app.conditionCount(for: $0) == 0 }) {
                        Text("None yet · showing a mix")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                            .transition(.opacity)
                    }
                }
            }
            .animation(.easeOut(duration: 0.2), value: focusStored)
        }
    }

    /// Today's graded cases against the daily goal ("1 of 2 today"), green once it's met.
    private var dailyCount: some View {
        let goal = DailyGoal(stored: dailyGoalStored).cases
        let done = app.gradedToday
        return Text("\(min(done, goal)) of \(goal) today")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(done >= goal ? Theme.accentText : Theme.muted)
            .contentTransition(.numericText())
            .accessibilityLabel("\(done) of \(goal) cases done today")
    }

    /// The focus label, with the care setting when one is picked ("Surgery · Clinic").
    private var chipLabel: String {
        let setting = CareSetting(stored: settingStored)
        return setting == .any ? focus.label : "\(focus.label) · \(setting.label)"
    }

    /// What the deck puts first. Tapping opens the focus sheet.
    private var focusChip: some View {
        return Button { editingFocus = true } label: {
            HStack(spacing: 8) {
                AppIcon(.target, size: 18).foregroundStyle(Theme.accentText)
                Text(chipLabel).font(.system(size: 15, weight: .semibold))
                AppIcon(.chevronDown, size: 14).foregroundStyle(Theme.muted)
            }
            .foregroundStyle(Theme.text)
            .padding(.leading, 10)
            .padding(.trailing, 12)
            .frame(height: 36)
            .background(Theme.text.opacity(0.07), in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.ring, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Study focus: \(chipLabel)")
        .accessibilityHint("Changes which patients you see")
    }
}

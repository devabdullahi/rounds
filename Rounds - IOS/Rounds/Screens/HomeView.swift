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

private var homeHasPlayed = false

struct HomeView: View {
    @Environment(AppState.self) private var app
    var openProfile: () -> Void

    @State private var stage = homeHasPlayed ? 4 : -1

    var body: some View {
        ScrimScrollView {
            VStack(alignment: .leading, spacing: 24) {
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
    }

    private func play() async {
        guard !homeHasPlayed else { return }
        homeHasPlayed = true
        let marks = [TIMING.header, TIMING.card, TIMING.vitals, TIMING.quote, TIMING.cta]
        var elapsed = 0.0
        for (i, at) in marks.enumerated() {
            try? await Task.sleep(for: .seconds(at - elapsed))
            elapsed = at
            withAnimation(.easeOut(duration: 0.3)) { stage = i }
        }
    }

    // MARK: Sections

    /// Settings › Appearance: 0 = System, 1 = Light, 2 = Dark.
    @AppStorage("appearance") private var appearance = 0

    /// An explicit Light/Dark choice sets the shift; System follows the clock (07:00–18:59 is day).
    private var shiftTitle: String {
        switch appearance {
        case 1: return "Day shift"
        case 2: return "Night shift"
        default:
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
                Button(action: openProfile) {
                    HStack(spacing: 6) {
                        StreakFlame(size: 16, color: .white)
                        Text("\(app.streak)").font(.mono(15))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassCapsule(tint: Theme.streak)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("\(app.streak) day streak")
            }

            Text(shiftTitle)
                .font(.system(size: 34, weight: .bold))
                .tracking(-0.5)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

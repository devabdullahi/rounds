import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Streak spotlight
 *
 *    0ms   backdrop fades in (250ms)
 *   80ms   symbol springs in, scale 0.6 → 1
 *  220ms   day count rises, y 12 → 0, fades in
 *  320ms   caption fades in
 *  tap     everything fades out together (200ms)
 *
 * Reduce Motion: no spring or rise; everything fades in at once.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let symbol = 0.08
    static let count = 0.22
    static let caption = 0.32
    static let rise: CGFloat = 12
}

/// The streak, big and centred: a snowflake at 0 days, otherwise the flame at its current heat
/// and weekly colour, with the day count and how long is left. Tap anywhere to close.
struct StreakSpotlight: View {
    let days: Int
    /// Flame heat, 0…1 (see `Streak.heat`).
    let heat: Double
    /// The week's colour, or the cold colour at 0 days.
    let tint: Color
    let caption: String
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stage = 0

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            Theme.bg.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 18) {
                symbol
                    .frame(width: 168, height: 168)
                    .background(Circle().fill(tint.opacity(0.14)))
                    .scaleEffect(stage >= 1 || reduceMotion ? 1 : 0.6)
                    .opacity(stage >= 1 ? 1 : 0)

                Text(Streak.daysText(days))
                    .font(.score(44))
                    .foregroundStyle(Theme.text)
                    .offset(y: stage >= 2 || reduceMotion ? 0 : TIMING.rise)
                    .opacity(stage >= 2 ? 1 : 0)

                Text(caption)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(stage >= 3 ? 1 : 0)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onClose)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Streak.daysText(days)) streak. \(caption)")
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onClose)
        .accessibilityAction(named: "Close", onClose)
        .task { await play() }
    }

    @ViewBuilder private var symbol: some View {
        if days == 0 {
            AppIcon(.snowflake, size: 96).foregroundStyle(tint)
        } else {
            StreakFlame(size: 104, color: tint, heat: heat)
        }
    }

    private func play() async {
        guard !reduceMotion else {
            withAnimation(.easeOut(duration: 0.25)) { stage = 3 }
            return
        }
        try? await Task.sleep(for: .seconds(TIMING.symbol))
        withAnimation(Springs.pop) { stage = 1 }
        try? await Task.sleep(for: .seconds(TIMING.count - TIMING.symbol))
        withAnimation(Springs.slide) { stage = 2 }
        try? await Task.sleep(for: .seconds(TIMING.caption - TIMING.count))
        withAnimation(.easeOut(duration: 0.25)) { stage = 3 }
    }
}

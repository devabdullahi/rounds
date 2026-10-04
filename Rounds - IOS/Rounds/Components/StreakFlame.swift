import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Streak flame
 *
 * IGNITE (on appear)
 *    0ms   flame grows from its base, scale 0.3 → 1.0 (bouncy)
 *    0ms   glow fades in
 *
 * BURN (continuous, never visibly loops)
 *   live   flicker: height ±6%, width counter-scales to keep volume
 *   live   sway: leans ±3° from its base, slower than the flicker
 *   live   glow breathes with the flicker (dark mode only)
 *   live   embers: 2 sparks drift up 10pt and fade (1.8s, offset)
 *
 * Flicker is three out-of-phase sine waves summed, which reads as
 * fire rather than a metronome.
 * Reduce Motion: static flame, no embers.
 * ───────────────────────────────────────────────────────── */

private enum FLAME {
    static let stretch: CGFloat = 0.06         // ± height change from flicker
    static let sway: Double = 3                 // ± degrees of lean
    static let swaySpeed = 2.3                  // rad/s, slow lean
    static let flickerSpeeds = (7.3, 11.1, 17.9)  // rad/s of the three flicker waves
    static let ignite = Animation.spring(response: 0.45, dampingFraction: 0.5)
    static let igniteFrom: CGFloat = 0.3
    static let glowBase = 0.35
    static let glowRange = 0.25
}

private enum EMBER {
    static let count = 2
    static let period = 1.8          // s per spark lifetime
    static let rise: CGFloat = 10    // pt each spark climbs
    static let drift: CGFloat = 3    // pt sideways wander
    static let size: CGFloat = 2.2
}

struct StreakFlame: View {
    var size: CGFloat = 16
    var color: Color = Theme.streak

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lit = false

    var body: some View {
        Group {
            if reduceMotion {
                AppIcon(.flame, size: size).foregroundStyle(color)
            } else {
                TimelineView(.animation) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    let (a, b, c) = FLAME.flickerSpeeds
                    let flicker = CGFloat(0.5 * sin(t * a) + 0.3 * sin(t * b + 1.2) + 0.2 * sin(t * c + 2.1))
                    let lean = FLAME.sway * sin(t * FLAME.swaySpeed) + 0.8 * Double(flicker)

                    ZStack(alignment: .bottom) {
                        embers(at: t)
                        AppIcon(.flame, size: size)
                            .foregroundStyle(color)
                            .shadow(color: Theme.glow(color, FLAME.glowBase + FLAME.glowRange * Double(flicker)),
                                    radius: 3 + 2 * flicker)
                            .scaleEffect(x: 1 - FLAME.stretch * 0.5 * flicker,
                                         y: 1 + FLAME.stretch * flicker,
                                         anchor: .bottom)
                            .rotationEffect(.degrees(lean), anchor: .bottom)
                    }
                }
                .scaleEffect(lit ? 1 : FLAME.igniteFrom, anchor: .bottom)
                .opacity(lit ? 1 : 0)
                .onAppear { withAnimation(FLAME.ignite) { lit = true } }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func embers(at t: Double) -> some View {
        ZStack {
            ForEach(0..<EMBER.count, id: \.self) { i in
                let phase = ((t / EMBER.period) + Double(i) / Double(EMBER.count)).truncatingRemainder(dividingBy: 1)
                Circle()
                    .fill(color)
                    .frame(width: EMBER.size, height: EMBER.size)
                    .offset(x: EMBER.drift * CGFloat(sin(t * 3 + Double(i) * 2)),
                            y: -size * 0.45 - EMBER.rise * CGFloat(phase))
                    .opacity((1 - phase) * 0.8)
            }
        }
    }
}

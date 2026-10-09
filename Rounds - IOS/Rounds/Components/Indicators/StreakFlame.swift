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
 *
 * HEAT (0…1, grows a little each day of streak)
 *   size   75% → 100% of the frame
 *   live   flicker, glow and sway scale with heat: day 1 barely moves
 *   embers none below 0.5, one from 0.5, two from 0.85
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
    /// How hot it burns, 0…1 (see `Streak.heat`); 1 is the full flame.
    var heat: Double = 1

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
                    let liveliness: Double = 0.3 + 0.7 * heat   // a new streak's flame barely flickers
                    let waves: Double = 0.5 * sin(t * a) + 0.3 * sin(t * b + 1.2) + 0.2 * sin(t * c + 2.1)
                    let flicker = CGFloat(liveliness * waves)
                    let sway: Double = liveliness * FLAME.sway * sin(t * FLAME.swaySpeed)
                    let lean: Double = sway + 0.8 * Double(flicker)
                    let glow: Double = heat * (FLAME.glowBase + FLAME.glowRange * Double(flicker))
                    let glowRadius: CGFloat = (3 + 2 * flicker) * CGFloat(heat)

                    ZStack(alignment: .bottom) {
                        embers(at: t)
                        AppIcon(.flame, size: size)
                            .foregroundStyle(color)
                            .shadow(color: Theme.glow(color, glow), radius: glowRadius)
                            .scaleEffect(x: 1 - FLAME.stretch * 0.5 * flicker,
                                         y: 1 + FLAME.stretch * flicker,
                                         anchor: .bottom)
                            .rotationEffect(.degrees(lean), anchor: .bottom)
                    }
                }
                .scaleEffect((lit ? 1 : FLAME.igniteFrom) * (0.75 + 0.25 * CGFloat(heat)), anchor: .bottom)
                .opacity(lit ? 1 : 0)
                .onAppear { withAnimation(FLAME.ignite) { lit = true } }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// Sparks only once the streak has some heat to it.
    private var emberCount: Int { heat >= 0.85 ? EMBER.count : heat >= 0.5 ? 1 : 0 }

    private func embers(at t: Double) -> some View {
        ZStack {
            ForEach(0..<emberCount, id: \.self) { i in
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

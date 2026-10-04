import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Home glow backdrop (Metal)
 *
 *   live   Shaders/Glow.metal draws three soft colour fields
 *          (mint · blue · peach in light / blue · violet · pink in dark)
 *          over the background, per pixel on the GPU
 *   live   fields chase each other around an infinity loop (∞) across the top,
 *          a third of a loop apart (≈ 10s per loop)
 *   live   each field's radius breathes ±15%
 *   static glow fades out by mid-screen; the bottom stays the plain background
 *   static fine grain dithered in, so the gradient never bands
 * Reduce Motion: time is frozen; the gradient holds still.
 * ───────────────────────────────────────────────────────── */

private enum GLOW {
    static let lightIntensity: Float = 0.55    // how strongly each field tints the background
    static let darkIntensity: Float = 0.40
    static let speed: Float = 1.0               // 1 = ~10s per infinity loop; raise for faster motion
}

struct GlowBackdrop: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let start = Date.now

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { ctx in
            let t = Float(ctx.date.timeIntervalSince(start))
            GeometryReader { geo in
                Rectangle()
                    .fill(.white)
                    .colorEffect(
                        ShaderLibrary.glowField(
                            .float2(geo.size),
                            .float(t),
                            .color(Theme.glowA),
                            .color(Theme.glowB),
                            .color(Theme.glowC),
                            .color(Theme.bg),
                            .float(scheme == .dark ? GLOW.darkIntensity : GLOW.lightIntensity),
                            .float(GLOW.speed)
                        )
                    )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

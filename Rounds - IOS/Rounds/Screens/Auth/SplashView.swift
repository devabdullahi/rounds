import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Launch splash
 *
 * Plays on every cold launch (app was closed, not just backgrounded),
 * then hands off to Sign in or Home. Continues seamlessly from the
 * static iOS launch screen (same background color). Animation only:
 * no title, no text.
 *
 *    0ms   ECG trace draws left → right (1100ms, ease in-out)
 * 1500ms   splash fades out (350ms) into the app
 *
 * Tap anywhere to skip. Reduce Motion: static trace, fades after 600ms.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let finish = 1.5         // trace done + a short beat to land
    static let reducedFinish = 0.6
}

private enum TRACE {
    static let curve = Animation.timingCurve(0.65, 0, 0.35, 1, duration: 1.1)
    static let height: CGFloat = 64
    static let lineWidth: CGFloat = 1.8
}

struct SplashView: View {
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat = 0
    @State private var finished = false

    var body: some View {
        ECGMarks.wide
            .trim(from: 0, to: drawn)
            .stroke(Theme.accent, style: StrokeStyle(lineWidth: TRACE.lineWidth, lineCap: .round, lineJoin: .round))
            .shadow(color: Theme.glow(Theme.accent, 0.6), radius: 6)
            .frame(height: TRACE.height)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bg.ignoresSafeArea())
            .contentShape(Rectangle())
            .onTapGesture(perform: finish)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Rounds")
            .task { await play() }
    }

    private func play() async {
        if reduceMotion {
            drawn = 1
            try? await Task.sleep(for: .seconds(TIMING.reducedFinish))
        } else {
            withAnimation(TRACE.curve) { drawn = 1 }
            try? await Task.sleep(for: .seconds(TIMING.finish))
        }
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinish()
    }
}

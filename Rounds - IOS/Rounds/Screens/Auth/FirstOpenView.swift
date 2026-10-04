import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · First open
 *
 * First launch only. Runs while sign-in state and config load.
 *
 *    0ms   ECG trace draws left → right (1400ms, ease in-out)
 * 1100ms   "Rounds" rises, y 8 → 0
 * 1400ms   status line rises; its dot pulses (1.2s loop)
 * 1800ms   "Get started" + "I already have an account" rise
 *
 * Reduce Motion: everything appears at once, no pulse.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let title   = 1.1   // wordmark rises as the trace finishes
    static let status  = 1.4   // "your shift starts now"
    static let cta     = 1.8   // Get started
}

private enum TRACE {
    static let duration = 1.4
    static let curve = Animation.timingCurve(0.65, 0, 0.35, 1, duration: duration)
    static let height: CGFloat = 64
    static let lineWidth: CGFloat = 1.8
}

private enum TEXTRISE {
    static let offset: CGFloat = 8
    static let curve = Animation.easeOut(duration: 0.5)
}

private enum DOT {
    static let period = 1.2
    static let dim = 0.35
}

struct FirstOpenView: View {
    var onGetStarted: () -> Void
    var onHaveAccount: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat = 0
    @State private var shown = false
    @State private var dotOn = true

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 22) {
                ECGMarks.wide
                    .trim(from: 0, to: drawn)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: TRACE.lineWidth, lineCap: .round, lineJoin: .round))
                    .shadow(color: Theme.accent.opacity(0.6), radius: 6)
                    .frame(height: TRACE.height)
                    .accessibilityHidden(true)

                Text("Rounds")
                    .font(.system(size: 44, weight: .bold))
                    .tracking(-1)
                    .opacity(shown ? 1 : 0)
                    .offset(y: shown ? 0 : TEXTRISE.offset)
                    .animation(TEXTRISE.curve.delay(TIMING.title), value: shown)

                HStack(spacing: 8) {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 8, height: 8)
                        .shadow(color: Theme.accent, radius: 4)
                        .opacity(dotOn ? 1 : DOT.dim)
                    Text("YOUR SHIFT STARTS NOW")
                        .font(.mono(13, weight: .medium))
                        .tracking(1)
                        .foregroundStyle(Theme.muted)
                }
                .opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : TEXTRISE.offset)
                .animation(TEXTRISE.curve.delay(TIMING.status), value: shown)
            }
            Spacer()

            VStack(spacing: 6) {
                Button("Get started", action: onGetStarted)
                    .buttonStyle(PrimaryButtonStyle(height: 52))
                Button("I already have an account", action: onHaveAccount)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(minHeight: 44)
            }
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : TEXTRISE.offset)
            .animation(TEXTRISE.curve.delay(TIMING.cta), value: shown)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg.ignoresSafeArea())
        #if DEBUG
        .devSkip()
        #endif
        .onAppear(perform: play)
    }

    private func play() {
        guard !reduceMotion else { drawn = 1; shown = true; return }
        withAnimation(TRACE.curve) { drawn = 1 }
        shown = true
        withAnimation(.easeInOut(duration: DOT.period / 2).repeatForever(autoreverses: true).delay(TIMING.status)) {
            dotOn = false
        }
    }
}

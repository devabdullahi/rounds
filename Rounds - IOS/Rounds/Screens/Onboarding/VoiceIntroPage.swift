import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Talk to your patients out loud
 *
 *    0ms   phone rises, y 24 → 0
 *  250ms   speech bubble pops from its tail
 *  550ms   mic button pops, then breathes with a soft ring (loop)
 *  700ms   sound bars start bouncing (loop, staggered)
 *  800ms   heartbeat badge pops
 * Reduce Motion: final art, nothing moves.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let bubble = 0.25
    static let mic = 0.55
    static let badge = 0.8
}

/// "Talk to your patients out loud": the voice mode pitch, before the tour. Continue keeps voice
/// on and goes to the tour; the page's "Type instead" turns voice off and skips it.
struct VoiceIntroPage: View {
    var shown = true
    @State private var arrived = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 0)
            art
                .frame(width: 240, height: 210)
                .accessibilityHidden(true)
            Text("Talk to your patients out loud")
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.5)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.text)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .onChange(of: shown, initial: true) { _, now in if now { arrived = true } }
    }

    private var art: some View {
        ZStack(alignment: .topLeading) {
            // The student's question, waiting to be said.
            VStack(alignment: .leading, spacing: 8) {
                Capsule().fill(Theme.faint).frame(width: 70, height: 7)
                Capsule().fill(Theme.faint).frame(width: 48, height: 7)
            }
            .padding(.horizontal, 16)
            .frame(width: 112, height: 56, alignment: .leading)
            .background(Theme.track, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .offset(x: 10, y: 34)
            .scaleEffect(arrived || reduceMotion ? 1 : 0.6, anchor: .bottomLeading)
            .opacity(arrived ? 1 : 0)
            .animation(reduceMotion ? nil : Springs.pop.delay(TIMING.bubble), value: arrived)

            phone
                .offset(x: 112, y: 44)
                .offset(y: arrived || reduceMotion ? 0 : 24)
                .opacity(arrived ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: arrived)

            AppIcon(.audioLines, size: 16)
                .foregroundStyle(Theme.accentText)
                .frame(width: 30, height: 30)
                .background(Theme.accentSoft, in: Circle())
                .offset(x: 200, y: 40)
                .scaleEffect(arrived || reduceMotion ? 1 : 0.6)
                .opacity(arrived ? 1 : 0)
                .animation(reduceMotion ? nil : Springs.pop.delay(TIMING.badge), value: arrived)
        }
    }

    private var phone: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Theme.text)
            .frame(width: 84, height: 150)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.surface)
                    .padding(7)
                    .overlay {
                        VStack(spacing: 18) {
                            bars
                            micButton
                        }
                    }
            }
    }

    private var bars: some View {
        TimelineView(.animation(paused: reduceMotion || !arrived)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    let wave = reduceMotion ? 0.7 : 0.4 + 0.6 * abs(sin(t * 3.2 + Double(i) * 0.6))
                    Capsule()
                        .fill(Theme.good)
                        .frame(width: 4, height: [12, 24, 36, 20, 40, 24, 12][i] * wave)
                }
            }
            .frame(height: 40)
        }
    }

    private var micButton: some View {
        TimelineView(.animation(paused: reduceMotion || !arrived)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let breath = reduceMotion ? 1 : 1 + 0.07 * sin(t * .pi)
            let ring = reduceMotion ? 0 : (t.truncatingRemainder(dividingBy: 2) / 2)
            ZStack {
                Circle().stroke(Theme.accent, lineWidth: 2)
                    .frame(width: 44, height: 44)
                    .scaleEffect(1 + ring * 0.8)
                    .opacity(reduceMotion ? 0 : 0.5 * (1 - ring))
                AppIcon(.mic, size: 18)
                    .foregroundStyle(Theme.accentInk)
                    .frame(width: 44, height: 44)
                    .background(Theme.accentFill, in: Circle())
                    .scaleEffect(breath)
            }
        }
        .scaleEffect(arrived || reduceMotion ? 1 : 0.6)
        .opacity(arrived ? 1 : 0)
        .animation(reduceMotion ? nil : Springs.pop.delay(TIMING.mic), value: arrived)
    }
}

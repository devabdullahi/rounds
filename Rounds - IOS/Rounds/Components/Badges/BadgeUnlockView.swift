import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Badge unlock (Rarity Burst)
 *
 *    0ms   scrim fades in; the card back rises in, scale 0.9 → 1
 *  150ms   charge: a glow in the card's rarity ink builds (900ms, ease-in)
 *          while the card hovers; light taps at 450, 700 and 850ms
 * 1050ms   burst: flash blooms, 9 shards fly out, the card flips to its
 *          front (spring); heavy impact
 * 1500ms   rarity label, name and how it was earned rise; success haptic;
 *          the Add to collection button appears
 *
 * Bigger for rarer cards, so the big moments stay special (the times
 * above are Epic and Legendary):
 *   Common     no charge-up: flips at 350ms, no shards, light tap
 *   Rare       shorter charge (500ms), 5 shards, medium impact
 *   Legendary  14 shards instead of 9
 *
 * Tap anywhere to skip to the end. Reduce Motion: the front at once,
 * caption and button, success haptic only.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let charge = 0.15          // s, charge-up starts
    static let chargeLength = 0.9     // s, glow build
    static let taps = [0.45, 0.70, 0.85]
    static let burst = 1.05           // s, flash + flip
    static let caption = 1.5          // s, text and button
}

private enum BURST {
    static let flip = Animation.spring(response: 0.42, dampingFraction: 0.72)
    static let shardDistance: CGFloat = 160
    static let cardScale: CGFloat = 1.2
}

/// How big the moment is for a rarity: rarer cards charge longer and burst bigger.
private struct Intensity {
    var charge: Double          // s, charge-up starts
    var chargeLength: Double    // s, glow build (0: none)
    var taps: [Double]          // s after the charge starts
    var burst: Double           // s, flash + flip
    var caption: Double         // s, text and button
    var shards: Int
    var flash: Bool
    var impact: SensoryFeedback.Weight

    init(_ rarity: Badge.Rarity) {
        switch rarity {
        case .common:
            self = Intensity(charge: 0, chargeLength: 0, taps: [], burst: 0.35, caption: 0.8, shards: 0, flash: false, impact: .light)
        case .rare:
            self = Intensity(charge: 0.1, chargeLength: 0.5, taps: [0.25, 0.4], burst: 0.6, caption: 1.05, shards: 5, flash: true, impact: .medium)
        case .epic:
            self = Intensity(charge: TIMING.charge, chargeLength: TIMING.chargeLength, taps: TIMING.taps, burst: TIMING.burst,
                             caption: TIMING.caption, shards: 9, flash: true, impact: .heavy)
        case .legendary:
            self = Intensity(charge: TIMING.charge, chargeLength: TIMING.chargeLength, taps: TIMING.taps, burst: TIMING.burst,
                             caption: TIMING.caption, shards: 14, flash: true, impact: .heavy)
        }
    }

    private init(charge: Double, chargeLength: Double, taps: [Double], burst: Double, caption: Double,
                 shards: Int, flash: Bool, impact: SensoryFeedback.Weight) {
        self.charge = charge; self.chargeLength = chargeLength; self.taps = taps; self.burst = burst
        self.caption = caption; self.shards = shards; self.flash = flash; self.impact = impact
    }
}

/// The moment a badge unlocks: the card back charges up in its rarity color, bursts, and turns
/// over. Shown over everything, once per badge.
struct BadgeUnlockView: View {
    let status: BadgeStatus
    let onCollect: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Stage: Int, Comparable {
        case idle, rising, charging, burst, done
        static func < (a: Stage, b: Stage) -> Bool { a.rawValue < b.rawValue }
    }

    @State private var stage = Stage.idle
    @State private var angle: Double = 0
    @State private var charge: Double = 0
    @State private var hover = false
    @State private var flashScale: CGFloat = 0.3
    @State private var flashOpacity: Double = 0
    /// -1 hidden, 0 at the card, 1 flown out.
    @State private var shards: Double = -1
    @State private var taps = 0

    private var ink: Color { status.badge.rarity.ink }
    private var intensity: Intensity { Intensity(status.badge.rarity) }

    var body: some View {
        ZStack {
            Color.black.opacity(stage >= .rising ? 0.85 : 0)
                .ignoresSafeArea()

            Circle()
                .fill(RadialGradient(colors: [.white.opacity(0.95), ink.opacity(0.45), ink.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: 180))
                .frame(width: 360, height: 360)
                .scaleEffect(flashScale)
                .opacity(flashOpacity)
                .allowsHitTesting(false)

            VStack(spacing: 28) {
                ZStack {
                    ForEach(0..<intensity.shards, id: \.self) { i in shard(i) }
                    FlipCard(angle: angle, status: status)
                        .shadow(color: ink.opacity(0.9 * charge), radius: 4 + 46 * charge)
                        .offset(y: hover ? -6 : 0)
                        .rotationEffect(.degrees(hover ? -1.5 : 0))
                        .scaleEffect(BURST.cardScale * (stage >= .rising ? 1 : 0.9))
                        .opacity(stage >= .rising ? 1 : 0)
                }
                .frame(height: BadgeCard.size.height * BURST.cardScale)

                VStack(spacing: 8) {
                    Text("\(status.badge.rarity.label.uppercased()) CARD")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(ink)
                    Text(status.badge.name)
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.4)
                        .foregroundStyle(.white)
                    Text(status.badge.achieved)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.cardInk)
                        .multilineTextAlignment(.center)
                    Button("Add to collection", action: onCollect)
                        .buttonStyle(PrimaryButtonStyle(height: 52))
                        .padding(.top, 16)
                }
                .padding(.horizontal, 32)
                .opacity(stage == .done ? 1 : 0)
                .offset(y: stage == .done ? 0 : 12)
                .allowsHitTesting(stage == .done)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if stage < .done { skip() } }
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
        .sensoryFeedback(.impact(weight: intensity.impact), trigger: stage) { _, new in new == .burst }
        .sensoryFeedback(.success, trigger: stage) { _, new in new == .done }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .task { await play() }
    }

    /// One shard of the burst, flying out along its own angle.
    private func shard(_ index: Int) -> some View {
        let angle = Double(index) / Double(max(1, intensity.shards)) * 2 * .pi
        let distance = BURST.shardDistance * CGFloat(max(0, shards))
        return Rectangle()
            .fill(ink)
            .frame(width: 9, height: 9)
            .rotationEffect(.degrees(45))
            .offset(x: CGFloat(cos(angle)) * distance, y: CGFloat(sin(angle)) * distance)
            .opacity(shards < 0 ? 0 : 1 - shards)
    }

    private func play() async {
        guard !reduceMotion else { skip(); return }
        let start = ContinuousClock.now
        func wait(until seconds: Double) async -> Bool {
            try? await Task.sleep(until: start + .seconds(seconds), clock: .continuous)
            return !Task.isCancelled && stage < .done
        }

        let moment = intensity
        withAnimation(.easeOut(duration: 0.3)) { stage = .rising }
        if moment.chargeLength > 0 {
            guard await wait(until: moment.charge) else { return }
            stage = .charging
            withAnimation(.easeIn(duration: moment.chargeLength)) { charge = 1 }
            withAnimation(.easeInOut(duration: 0.15).repeatCount(moment.taps.count * 2, autoreverses: true)) { hover = true }
            for tap in moment.taps {
                guard await wait(until: moment.charge + tap) else { return }
                taps += 1
            }
        }

        guard await wait(until: moment.burst) else { return }
        var still = Transaction(); still.disablesAnimations = true
        withTransaction(still) { hover = false; shards = 0 }
        stage = .burst
        if moment.flash {
            withAnimation(.easeOut(duration: 0.15)) { flashOpacity = 1; flashScale = 0.8 }
            withAnimation(.easeOut(duration: 0.6)) { flashScale = 1.4 }
        }
        withAnimation(.easeOut(duration: 0.64)) { shards = 1 }
        withAnimation(BURST.flip) { angle = 180 }
        withAnimation(.easeOut(duration: 0.5)) { charge = 0.35 }
        guard await wait(until: moment.burst + 0.2) else { return }
        withAnimation(.easeOut(duration: 0.4)) { flashOpacity = 0 }

        guard await wait(until: moment.caption) else { return }
        withAnimation(.easeOut(duration: 0.32)) { stage = .done }
    }

    /// Straight to the end: front up, caption and button showing.
    private func skip() {
        var still = Transaction(); still.disablesAnimations = true
        withTransaction(still) {
            angle = 180; charge = 0.35; hover = false; shards = -1; flashOpacity = 0
        }
        withAnimation(.easeOut(duration: 0.2)) { stage = .done }
    }
}

/// The card turning over: the back until halfway, then the front. Animatable so the face swaps
/// at exactly 90° on every frame of the spring.
private struct FlipCard: View, Animatable {
    var angle: Double
    let status: BadgeStatus

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        ZStack {
            BadgeCardBack(progress: nil)
                .opacity(angle < 90 ? 1 : 0)
            BadgeCardFront(status: status)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(angle >= 90 ? 1 : 0)
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
    }
}

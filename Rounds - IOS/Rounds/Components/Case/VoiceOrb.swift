import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Voice orb
 *
 * YOUR TURN (listening)
 *    live   orb edge wobbles; wobble amplitude 0.02 → 0.085 with mic level
 *    live   orb swells, scale 1.0 → 1.28 with mic level
 *    live   3 rings ripple out after the orb (staggered 70ms, chained)
 *
 * QUESTION SENT (thinking)
 *    0ms    orb settles to 0.92, slow breath ±2% (1.6s cycle)
 *
 * PATIENT'S TURN (speaking)
 *    0ms    orb compresses 1.0 → 0.84, squashes y 0.94, tints blue
 *    live   each spoken word pulses scale +0.07, rings stay tight
 *
 * BACK TO YOU
 *    0ms    orb springs past rest 0.84 → ~1.06 → 1.0 (bouncy release)
 *
 * Every change is a spring on current state, so taps mid-transition
 * (interrupting the patient) redirect smoothly instead of snapping.
 * ───────────────────────────────────────────────────────── */

private enum ORB {
    static let size: CGFloat = 132
    static let listenGain: CGFloat = 0.28        // extra scale at full mic level
    static let thinkingScale: CGFloat = 0.92
    static let breathAmount: CGFloat = 0.02
    static let breathPeriod = 1.6                // s
    static let patientScale: CGFloat = 0.84      // compressed while the patient talks
    static let patientSquashY: CGFloat = 0.94
    static let patientPulseGain: CGFloat = 0.07
    static let wobbleIdle: CGFloat = 0.02
    static let wobbleGain: CGFloat = 0.065
    static let wobbleSpeed = 1.8                 // rad/s of the edge noise
    static let compress = Animation.spring(response: 0.35, dampingFraction: 0.72)
    static let release  = Animation.spring(response: 0.5, dampingFraction: 0.5)   // overshoots on purpose
    static let follow   = Animation.spring(response: 0.16, dampingFraction: 0.8)  // tracks the voice
}

private enum RINGS {
    static let count = 3
    static let stagger = 0.07                    // s between rings: chain, don't move as one block
    static let spread: CGFloat = 0.22            // extra scale per ring at full level
    static let baseOpacity = 0.32
}

struct VoiceOrb: View {
    let phase: VoiceController.Phase
    let level: CGFloat

    private var isPatient: Bool { phase == .patientSpeaking }
    private var tint: Color { isPatient ? Theme.info : Theme.accent }

    /// Phase-level resting scale, animated with springs between turns.
    private var restScale: CGFloat {
        switch phase {
        case .patientSpeaking: ORB.patientScale
        case .thinking: ORB.thinkingScale
        default: 1
        }
    }

    /// Live response to the voice, layered on top of the resting scale.
    private var liveScale: CGFloat {
        switch phase {
        case .listening: 1 + level * ORB.listenGain
        case .patientSpeaking: 1 + level * ORB.patientPulseGain
        default: 1
        }
    }

    private var ringLevel: CGFloat { phase == .listening ? level : level * 0.3 }

    var body: some View {
        ZStack {
            ForEach(0..<RINGS.count, id: \.self) { i in
                Circle()
                    .stroke(tint.opacity(RINGS.baseOpacity - Double(i) * 0.09), lineWidth: 1.5)
                    .scaleEffect(1 + RINGS.spread * CGFloat(i + 1) * ringLevel)
                    .opacity(ringLevel > 0.04 ? 1 : 0)
                    .animation(ORB.follow.delay(Double(i) * RINGS.stagger), value: ringLevel)
            }

            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let breath = phase == .thinking ? 1 + ORB.breathAmount * CGFloat(sin(t * 2 * .pi / ORB.breathPeriod)) : 1
                BlobShape(phase: t * ORB.wobbleSpeed, amplitude: ORB.wobbleIdle + ORB.wobbleGain * (phase == .listening ? level : level * 0.4))
                    .fill(
                        RadialGradient(colors: [tint.opacity(0.95), tint.opacity(0.55)],
                                       center: UnitPoint(x: 0.38, y: 0.32), startRadius: 4, endRadius: ORB.size * 0.6)
                    )
                    .shadow(color: tint.opacity(0.35 + 0.35 * level), radius: 12 + 24 * level)
                    .scaleEffect(breath)
            }
            .scaleEffect(liveScale)
            .animation(ORB.follow, value: liveScale)
        }
        .frame(width: ORB.size, height: ORB.size)
        .scaleEffect(x: restScale, y: restScale * (isPatient ? ORB.patientSquashY : 1))
        .animation(isPatient ? ORB.compress : ORB.release, value: phase)
        .animation(.easeInOut(duration: 0.3), value: isPatient)
    }
}

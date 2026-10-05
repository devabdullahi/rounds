import SwiftUI

/* ANIMATION STORYBOARD · Anatomy loader (admitting a patient)
 *
 * One organ per beat, looping heart → brain → lungs → kidney → stomach.
 *    0ms   organ draws itself in a glowing line (800ms)
 *  800ms   holds, fully drawn (700ms)
 * 1500ms   line runs off from its start as the beat ends (500ms)
 * 2000ms   next organ begins drawing
 * The organ-system name under the drawing fades in with the line and out as it runs off.
 * The soft halo behind breathes on its own slower cycle.
 *
 * Reduce Motion: no loop; the heart sits fully drawn with its label.
 */
private enum TIMING {
    static let beat = 2.0           // s per organ
    static let draw = 0.40          // fraction of a beat spent drawing
    static let hold = 0.75          // fraction at which the line starts running off
    static let halo = 2.5           // s per halo breath
}

/// Line drawings of organs in a 120×120 box, one per organ system the app teaches.
/// Drawn as paths rather than icons because the effect trims the line as it draws.
private struct Organ {
    let label: String
    let d: String

    static let all = [
        Organ(label: OrganSystem.cardiovascular.label,
              d: "M38 46 C28 54 26 70 34 82 C44 96 60 106 74 108 C84 98 94 84 96 68 C98 52 90 42 78 42 C70 42 64 46 60 52 C54 44 46 42 38 46 Z M56 48 C54 32 58 20 70 18 C80 17 88 24 88 34 M64 19 V9 M71 18 V8 M78 19 V10 M46 46 V22 M66 46 C70 38 76 36 82 40 C86 42 92 42 96 38 M52 64 C60 72 64 82 62 96"),
        Organ(label: OrganSystem.nervous.label,
              d: "M60 26 C48 18 32 22 28 34 C18 38 16 52 24 60 C20 70 28 82 40 82 C46 92 58 92 60 84 C62 92 76 92 82 82 C94 82 102 70 96 60 C104 52 102 38 92 34 C88 22 72 18 60 26 Z M60 26 V84 M40 38 C47 42 47 50 40 55 M80 38 C73 42 73 50 80 55 M34 66 C42 63 49 68 49 75 M86 66 C78 63 71 68 71 75"),
        Organ(label: OrganSystem.respiratory.label,
              d: "M60 12 V44 M60 44 C55 49 51 51 46 54 M60 44 C65 49 69 51 74 54 M50 34 C38 34 24 54 22 76 C20 96 30 104 44 102 C52 100 54 92 54 80 V46 C54 40 52 34 50 34 Z M70 34 C82 34 96 54 98 76 C100 96 90 104 76 102 C68 100 66 92 66 80 V46 C66 40 68 34 70 34 Z"),
        Organ(label: OrganSystem.renal.label,
              d: "M70 16 C46 14 30 36 30 60 C30 86 46 104 68 102 C82 100 88 88 82 76 C78 68 70 66 70 60 C70 54 78 52 82 44 C88 32 82 18 70 16 Z M72 62 C82 64 90 74 92 90 V110"),
        Organ(label: OrganSystem.gastrointestinal.label,
              d: "M48 8 V30 C48 44 30 46 28 62 C26 82 44 98 66 96 C88 94 100 76 96 56 C94 44 84 38 76 44 C70 48 70 56 62 56 C56 56 56 44 56 30 V8 M66 96 C70 104 78 108 88 104"),
    ]
}

/// Organs drawing themselves one after another while a new patient is written.
struct AnatomyLoader: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var size: CGFloat = 170

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let cycle = TIMING.beat * Double(Organ.all.count)
            let index = reduceMotion ? 0 : Int((t.truncatingRemainder(dividingBy: cycle)) / TIMING.beat)
            let phase = reduceMotion ? TIMING.draw : (t.truncatingRemainder(dividingBy: TIMING.beat)) / TIMING.beat
            let organ = Organ.all[index]
            let (from, to) = Self.trim(phase)
            let breath = reduceMotion ? 0.5 : (sin(t * 2 * .pi / TIMING.halo) + 1) / 2

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Theme.accent.opacity(0.22), Theme.accent.opacity(0)],
                                             center: .center, startRadius: 0, endRadius: size * 0.55))
                        .scaleEffect(0.92 + 0.12 * breath)
                        .opacity(0.35 + 0.35 * breath)
                    SVGShape(d: organ.d, viewBox: CGSize(width: 120, height: 120))
                        .trim(from: from, to: to)
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3 * size / 120, lineCap: .round, lineJoin: .round))
                        .frame(width: size, height: size)
                        .shadow(color: Theme.glow(Theme.accent, 0.75), radius: 6)
                }
                .frame(width: size + 20, height: size + 20)

                Text(organ.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
                    .opacity(Self.labelOpacity(phase))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Admitting a new patient")
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// Where the drawn segment starts and ends at a point in the beat: grows from the start,
    /// holds, then runs off from the start so the line seems to leave by its tail.
    static func trim(_ phase: Double) -> (CGFloat, CGFloat) {
        if phase < TIMING.draw { return (0, ease(phase / TIMING.draw)) }
        if phase < TIMING.hold { return (0, 1) }
        return (ease((phase - TIMING.hold) / (1 - TIMING.hold)), 1)
    }

    static func labelOpacity(_ phase: Double) -> Double {
        if phase < 0.1 { return phase / 0.1 }
        if phase > 0.85 { return max(0, (1 - phase) / 0.15) }
        return 1
    }

    /// Ease in-out, close to the canvas mock's cubic-bezier(.45, 0, .2, 1).
    private static func ease(_ x: Double) -> CGFloat {
        CGFloat(x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2)
    }
}

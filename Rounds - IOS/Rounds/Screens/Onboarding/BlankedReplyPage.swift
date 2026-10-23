import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · After "Ever blanked?" (one scene per answer)
 *
 * ALL THE TIME   0ms   speech bubble rises, y 14 → 0 (ease-out)
 *                idle  its three dots bounce in turn (1.2s); the bubble floats 3pt (4s);
 *                      two small thought bubbles drift (6s)
 * SOMETIMES      0ms   a jagged red pulse draws across (900ms), then fades to a trace
 *              900ms   a calm green pulse draws over it (900ms, ease-in-out)
 *                idle  a dot travels the calm line (3s)
 * RARELY         0ms   the case card rises; History, Exam, Tests rise 350ms apart,
 *                      each ticking 250ms later
 *                idle  the card sways 1° on its clip (6s)
 * All three      headline and line rise once the scene has played.
 * Reduce Motion: each scene's final frame, still.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let jaggedDraw = 0.9
    static let calmDraw = 0.9
    static let rowGap = 0.35
    static let tickAfter = 0.25
    static let copy = 1.2
}

/// The encouraging beat after "Ever blanked on something you knew?": a small living scene for the
/// student's answer and two lines. It names no settings and changes none.
struct BlankedReplyPage: View {
    var shown = true
    @AppStorage(BlankFrequency.storageKey) private var stored = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var played = false

    private var answer: BlankFrequency { BlankFrequency(stored: stored) ?? .sometimes }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            ZStack {
                Circle().fill(wash).frame(width: 240, height: 240)
                TimelineView(.animation(paused: reduceMotion || !shown)) { ctx in
                    let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
                    switch answer {
                    case .often: bubbleScene(t)
                    case .sometimes: pulseScene(t)
                    case .rarely: caseScene(t)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .accessibilityHidden(true)

            Text(answer.replyHeadline)
                .font(.system(size: 34, weight: .bold)).tracking(-0.7)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 22)
                .rise(shown, at: TIMING.copy, offset: 8)
                .accessibilityAddTraits(.isHeader)
            Text(answer.replyLine)
                .font(.system(size: 17))
                .foregroundStyle(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
                .rise(shown, at: TIMING.copy + 0.15, offset: 8)
            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .onChange(of: shown, initial: true) { _, now in if now { played = true } }
    }

    /// The circle behind each scene: the same soft accent for all three, like the answer tiles.
    private var wash: Color { Theme.accentSoft }

    // MARK: All the time: dots that keep thinking

    private func bubbleScene(_ t: Double) -> some View {
        ZStack {
            Circle().fill(Theme.surface).frame(width: 18, height: 18)
                .overlay(Circle().strokeBorder(Theme.border, lineWidth: 2))
                .offset(x: -96 + 4 * sin(t / 6 * 2 * .pi), y: -52 - 6 * sin(t / 6 * 2 * .pi))
            Circle().fill(Theme.surface).frame(width: 10, height: 10)
                .overlay(Circle().strokeBorder(Theme.border, lineWidth: 2))
                .offset(x: -112 + 4 * sin((t + 1.5) / 6 * 2 * .pi), y: -76 - 6 * sin((t + 1.5) / 6 * 2 * .pi))
            HStack(spacing: 14) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(Theme.muted).frame(width: 12, height: 12)
                        .offset(y: -dotHop(t - Double(i) * 0.15))
                }
            }
            .frame(width: 190, height: 72)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.border, lineWidth: 2))
            .offset(y: (played || reduceMotion ? 0 : 14) - 3 * sin(t / 4 * 2 * .pi))
            .opacity(played || reduceMotion ? 1 : 0)
            .animation(reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: 0.5), value: played)
        }
    }

    /// A typing dot's lift: up and back in the first part of each 1.2s cycle, still for the rest.
    private func dotHop(_ t: Double) -> CGFloat {
        let p = (t.truncatingRemainder(dividingBy: 1.2) + 1.2).truncatingRemainder(dividingBy: 1.2) / 1.2
        return p < 0.5 ? 8 * sin(p / 0.5 * .pi) : 0
    }

    // MARK: Sometimes: a racing pulse settles

    private static let calm: [CGPoint] = [(0, 0), (80, 0), (92, -18), (104, 20), (116, 0), (200, 0), (212, -18), (224, 20), (236, 0), (300, 0)]
        .map { CGPoint(x: $0.0, y: $0.1) }

    private func pulseScene(_ t: Double) -> some View {
        ZStack {
            Path { p in
                let ys: [CGFloat] = [0, -40, 40, -60, 50, -34, 30, -50, 46, -30, 20, -44, 42, -26, 24, -20, 16, -12, 0]
                p.move(to: CGPoint(x: 0, y: 0))
                for (i, y) in ys.enumerated() { p.addLine(to: CGPoint(x: CGFloat(i) * 300 / CGFloat(ys.count - 1), y: y)) }
            }
            .trim(from: 0, to: played || reduceMotion ? 1 : 0)
            .stroke(Theme.wrong.opacity(played ? 0.15 : 0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .offset(y: 60)
            .animation(reduceMotion ? nil : .linear(duration: TIMING.jaggedDraw), value: played)
            Path { p in p.addLines(Self.calm) }
                .trim(from: 0, to: played || reduceMotion ? 1 : 0)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                .offset(y: 60)
                .animation(reduceMotion ? nil : .timingCurve(0.77, 0, 0.175, 1, duration: TIMING.calmDraw).delay(TIMING.jaggedDraw), value: played)
            if !reduceMotion {
                Circle().fill(Theme.accent).frame(width: 14, height: 14)
                    .position(point(on: Self.calm, at: (t / 3).truncatingRemainder(dividingBy: 1)))
                    .opacity(played ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(TIMING.jaggedDraw + TIMING.calmDraw), value: played)
            }
        }
        .frame(width: 300, height: 120)
    }

    /// A point a fraction of the way along a polyline, by length.
    private func point(on line: [CGPoint], at fraction: Double) -> CGPoint {
        let lengths = zip(line, line.dropFirst()).map { hypot($1.x - $0.x, $1.y - $0.y) }
        var left = lengths.reduce(0, +) * fraction
        for (i, length) in lengths.enumerated() {
            if left <= length {
                let a = line[i], b = line[i + 1], k = length == 0 ? 0 : left / length
                return CGPoint(x: a.x + (b.x - a.x) * k, y: a.y + (b.y - a.y) * k + 60)
            }
            left -= length
        }
        return CGPoint(x: line.last?.x ?? 0, y: (line.last?.y ?? 0) + 60)
    }

    // MARK: Rarely: a case that ticks off

    private func caseScene(_ t: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CASE").font(.system(size: 12, weight: .heavy)).tracking(1).foregroundStyle(Theme.muted)
            ForEach(Array(["History", "Exam", "Tests"].enumerated()), id: \.offset) { i, step in
                let at = 0.4 + Double(i) * TIMING.rowGap
                HStack {
                    Text(step).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                    Spacer()
                    AppIcon(.check, size: 12)
                        .foregroundStyle(Theme.accentInk)
                        .frame(width: 22, height: 22)
                        .background(Theme.accent, in: Circle())
                        .scaleEffect(played || reduceMotion ? 1 : 0.8)
                        .opacity(played || reduceMotion ? 1 : 0)
                        .animation(reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: 0.3).delay(at + TIMING.tickAfter), value: played)
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Theme.bg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .rise(played, at: at, offset: 10)
            }
        }
        .padding(16)
        .frame(width: 200)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.accent.opacity(0.3), lineWidth: 2))
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 6).fill(Theme.accent.opacity(0.45)).frame(width: 64, height: 16).offset(y: -8)
        }
        .rotationEffect(.degrees(reduceMotion ? 0 : sin(t / 6 * 2 * .pi)), anchor: .top)
        .rise(played, at: 0, offset: 10)
    }
}

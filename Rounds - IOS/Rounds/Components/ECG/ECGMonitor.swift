import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · ECG monitor
 *
 * Works like a bedside monitor: the sweep moves across at a steady
 * speed and the heart rate sets how close together the beats sit.
 *
 *   104 bpm   4 beats per sweep, one R wave every 577ms
 *   130 bpm   5 beats per sweep, one R wave every 462ms
 *
 *   live   bright head sweeps left → right, fading tail behind it
 *   wrap   head re-enters on the left while the old tail fades on the right
 *   beat   the head crosses an R wave exactly once per heartbeat
 *
 * At high rates the gap between beats shrinks first (as on a real
 * ECG); the complex itself only narrows once there's no gap left.
 *
 * Dark mode: glowing trace, like a bedside monitor.
 * Light mode: black ink on pink chart paper (1 mm / 5 mm grid), no glow.
 * ───────────────────────────────────────────────────────── */

/// Monitor-style sweep at a given heart rate. `flatline` keeps the sweep moving over a flat trace,
/// a monitor with nobody on it.
struct ECGMonitor: View {
    var bpm: Double = 104
    var color: Color = Theme.accent
    var stElevation = false
    var flatline = false
    var height: CGFloat = 40

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let paper = scheme == .light
        let color = paper ? Theme.text : color      // paper ECGs are printed in black ink
        let beats = ECG.beatsPerSweep(bpm)
        let window = ECG.window(bpm)
        let shape = ECGShape(beats: flatline ? 0 : beats, stElevation: stElevation)
        let style = StrokeStyle(lineWidth: ECG.lineWidth, lineCap: .round, lineJoin: .round)

        GeometryReader { geo in
            let w = geo.size.width
            let tailW = w * ECG.tail
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let head = CGFloat((t.truncatingRemainder(dividingBy: window)) / window) * w
                ZStack {
                    if paper { ECGPaperGrid() }
                    shape.stroke(color.opacity(paper ? 0.14 : 0.18), style: style)
                    shape.stroke(color, style: style)
                        .shadow(color: Theme.glow(color, 0.6), radius: 4)
                        .mask(alignment: .leading) {
                            ZStack(alignment: .leading) {
                                // Tail behind the head, plus its wrapped remainder on the right edge.
                                ForEach([head - tailW, head - tailW + w], id: \.self) { start in
                                    LinearGradient(colors: [.clear, .white], startPoint: .leading, endPoint: .trailing)
                                        .frame(width: tailW)
                                        .offset(x: start)
                                }
                            }
                            .frame(width: w, alignment: .leading)
                        }
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

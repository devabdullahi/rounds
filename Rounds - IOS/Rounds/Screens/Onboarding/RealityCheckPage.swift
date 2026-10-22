import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Reality check
 *
 *    0ms   label, headline and line rise, y 8 → 0 (ease-out)
 *  300ms   both paths draw left to right (1200ms, ease-in-out); the green one climbs
 * 1500ms   end labels fade in
 * Reduce Motion: the finished chart.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let draw = 0.3
    static let drawLength = 1.2
    static let labels = 1.5
}

/// Tough love after the confidence question, short enough to read in a glance and built only
/// from true things: the student's own number, their exam month and their plan's patient count.
/// Only shown with an exam month.
struct RealityCheckPage: View {
    var shown = true
    @AppStorage(DiagnosisConfidence.storageKey) private var confidenceStored = 0
    @AppStorage(ExamMonth.storageKey) private var examStored = ""
    @AppStorage(DailyGoal.storageKey) private var dailyGoalStored = DailyGoal.default.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn = false

    private var exam: ExamMonth? { ExamMonth(stored: examStored) }
    private var perDay: Int { DailyGoal(stored: dailyGoalStored).cases }
    private var total: Int { exam?.patients(perDay: perDay) ?? perDay * 7 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("REALITY CHECK")
                .font(.system(size: 13, weight: .heavy)).tracking(1)
                .foregroundStyle(Theme.warnText)
                .rise(shown, at: 0, offset: 8)
            Text(DiagnosisConfidence(stored: confidenceStored)?.headline ?? "Your exam is closer than it feels.")
                .font(.system(size: 30, weight: .bold)).tracking(-0.5)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .rise(shown, at: 0, offset: 8)
                .accessibilityAddTraits(.isHeader)
            Text("\(exam?.weeksLeft() ?? 0) weeks to go, and rotations rarely grade every case.")
                .font(.system(size: 16))
                .foregroundStyle(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .rise(shown, at: 0, offset: 8)

            chart
                .padding(16)
                .background(Theme.track, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.top, 22)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .onChange(of: shown, initial: true) { _, now in if now { drawn = true } }
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let end = CGPoint(x: w * 0.8, y: h * 0.12)
                let flatEnd = CGPoint(x: w * 0.8, y: h * 0.86)
                ZStack(alignment: .topLeading) {
                    Path { p in p.move(to: CGPoint(x: 0, y: h * 0.94)); p.addLine(to: CGPoint(x: w, y: h * 0.94)) }
                        .stroke(Theme.border, lineWidth: 1)
                    Path { p in
                        p.move(to: CGPoint(x: 6, y: h * 0.88))
                        p.addCurve(to: flatEnd, control1: CGPoint(x: w * 0.3, y: h * 0.88), control2: CGPoint(x: w * 0.55, y: h * 0.87))
                    }
                    .trim(from: 0, to: drawn || reduceMotion ? 1 : 0)
                    .stroke(Theme.faint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    Path { p in
                        p.move(to: CGPoint(x: 6, y: h * 0.88))
                        p.addCurve(to: end, control1: CGPoint(x: w * 0.25, y: h * 0.8), control2: CGPoint(x: w * 0.5, y: h * 0.55))
                    }
                    .trim(from: 0, to: drawn || reduceMotion ? 1 : 0)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    Group {
                        Circle().fill(Theme.accent).frame(width: 14, height: 14).position(end)
                        Text("\(total)").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.accentText)
                            .position(x: end.x + 26, y: end.y)
                        Circle().fill(Theme.faint).frame(width: 12, height: 12).position(flatEnd)
                        Text("a few").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.muted)
                            .position(x: flatEnd.x + 30, y: flatEnd.y)
                    }
                    .opacity(drawn || reduceMotion ? 1 : 0)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.4).delay(TIMING.labels), value: drawn)
                }
                .animation(reduceMotion ? nil : .timingCurve(0.77, 0, 0.175, 1, duration: TIMING.drawLength).delay(TIMING.draw), value: drawn)
            }
            .frame(height: 150)
            HStack {
                Text("Today")
                Spacer()
                Text(exam?.name() ?? "Test day")
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.muted)
            legend(Theme.accent, bold: "With Rounds:", rest: "\(total) graded cases")
            legend(Theme.faint, bold: nil, rest: "Rotations alone: a few")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Graded cases by test day. With Rounds at \(perDay) a day: \(total). Rotations alone: a few.")
    }

    private func legend(_ color: Color, bold: String?, rest: String) -> some View {
        HStack(spacing: 8) {
            Capsule().fill(color).frame(width: 14, height: 4)
            (bold.map { Text($0 + " ").bold() } ?? Text("")) + Text(rest)
        }
        .font(.system(size: 14))
        .foregroundStyle(bold == nil ? Theme.muted : Theme.text)
    }
}

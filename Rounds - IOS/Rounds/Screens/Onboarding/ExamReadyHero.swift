import SwiftUI

/// After the study goal: with vs. without Rounds, tagged with the exam just picked, as an illustration (no real data yet, so it says so).
struct ExamReadyHero: View {
    let shown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(StudyGoal.storageKey) private var goalStored = ""

    var body: some View {
        HeroCanvas {
            Sparkle().fill(Theme.surface).frame(width: 26, height: 26).at(318, 14).heroPop(shown, delay: 0.6)
            Sparkle().fill(Theme.sparkleBlue).frame(width: 22, height: 36).at(320, 344).heroPop(shown, delay: 0.65)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Conditions practiced").font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text(StudyGoal(stored: goalStored)?.examDayTag ?? "Exam day")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.warnText)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Theme.warnSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                ZStack(alignment: .topLeading) {
                    ForEach([60.0, 110, 160], id: \.self) { y in
                        Rectangle().fill(Theme.text.opacity(0.06)).frame(height: 1).offset(y: y)
                    }
                    WithCurve(closed: true).fill(Theme.accent.opacity(0.12))
                        .opacity(shown || reduceMotion ? 1 : 0)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.6).delay(0.5), value: shown)
                    WithoutCurve()
                        .stroke(Theme.faint, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [7, 6]))
                    WithCurve(closed: false)
                        .trim(from: 0, to: shown || reduceMotion ? 1 : 0)
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .animation(reduceMotion ? nil : .timingCurve(0.65, 0, 0.35, 1, duration: 0.9).delay(0.15), value: shown)
                    Rectangle().fill(Theme.wrong).frame(width: 2, height: 170).offset(x: 317, y: 10)
                    Rectangle().fill(Theme.text.opacity(0.2)).frame(height: 1).offset(y: 180)
                }
                .frame(width: 318, height: 200, alignment: .topLeading)
            }
            .padding(EdgeInsets(top: 18, leading: 16, bottom: 14, trailing: 16))
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Theme.text.opacity(0.12), radius: 24, y: 20)
            .at(0, 56)
            .heroPop(shown, delay: 0)

            HStack(spacing: 6) {
                AppIcon(.check, size: 14)
                Text("With Rounds").font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(Theme.accentInk)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Theme.accent.opacity(0.3), radius: 12, y: 10)
            .at(102, 98)
            .heroPop(shown, delay: 0.9)

            HeroTag(text: "Without", ink: Theme.muted).at(222, 238).heroPop(shown, delay: 1.0)

            Text("Illustration").font(.system(size: 11)).foregroundStyle(Theme.muted).at(16, 336)
        }
    }
}

/// The "with Rounds" line: a fast climb that levels off well before exam day (318×200 box).
private struct WithCurve: Shape {
    let closed: Bool
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 180))
        p.addCurve(to: CGPoint(x: 120, y: 28), control1: CGPoint(x: 40, y: 150), control2: CGPoint(x: 70, y: 60))
        p.addLine(to: CGPoint(x: 318, y: 22))
        if closed {
            p.addLine(to: CGPoint(x: 318, y: 180))
            p.closeSubpath()
        }
        return p
    }
}

/// The "without" line: a slow rise that ends far lower.
private struct WithoutCurve: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 180))
        p.addCurve(to: CGPoint(x: 318, y: 132), control1: CGPoint(x: 60, y: 172), control2: CGPoint(x: 140, y: 158))
        return p
    }
}

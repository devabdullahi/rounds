import SwiftUI

// Hero art for the four intro pages, laid out on HeroCanvas's 350×400 board. Each takes `shown`
// and pops its parts in with a short stagger (see OnboardingView's storyboard).

/// Page 1: a ring of fictional patients around "Diagnosis, nailed".
struct PatientsHero: View {
    let shown: Bool

    var body: some View {
        HeroCanvas {
            Ellipse().stroke(Theme.accent.opacity(0.14)).frame(width: 330, height: 160).at(10, 150)
            Ellipse().stroke(Theme.accent.opacity(0.12)).frame(width: 270, height: 100).at(40, 180)
            Sparkle().fill(Theme.surface).frame(width: 30, height: 30).at(18, 66).heroPop(shown, delay: 0.35)
            Sparkle().fill(Theme.surface).frame(width: 34, height: 56).at(242, 24).heroPop(shown, delay: 0.4)
            Sparkle().fill(Theme.sparkleBlue).frame(width: 18, height: 18).at(290, 300).heroPop(shown, delay: 0.45)

            PatientAvatar(initials: "RM", size: 112, tint: .blue).at(58, 50).heroPop(shown, delay: 0)
            HeroTag(text: "Ray, 58 · chest pain").at(34, 166).heroPop(shown, delay: 0.1)
            PatientAvatar(initials: "AL", size: 78, tint: .pink).at(204, 112).heroPop(shown, delay: 0.06)
            PatientAvatar(initials: "JT", size: 70, tint: .yellow).at(274, 36).heroPop(shown, delay: 0.12)
            PatientAvatar(initials: "EK", size: 66, tint: .purple).at(20, 330).heroPop(shown, delay: 0.18)
            PatientAvatar(initials: "SO", size: 58, tint: .mint).at(104, 318).heroPop(shown, delay: 0.22)
            PatientAvatar(initials: "MB", size: 96, tint: .rose).at(246, 300).heroPop(shown, delay: 0.26)

            IconPill(glyph: .stethoscope).at(0, 200).heroPop(shown, delay: 0.3)
            IconPill(glyph: .messageSquare).at(304, 214).heroPop(shown, delay: 0.34)
            IconPill(glyph: .flask).at(176, 360).heroPop(shown, delay: 0.38)

            HStack(spacing: 12) {
                CheckDot(size: 34)
                Text("Diagnosis, nailed")
                    .font(.system(size: 22, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(Theme.text)
            }
            .padding(.leading, 14)
            .padding(.trailing, 26)
            .frame(height: 64)
            .background(Theme.surface, in: Capsule())
            .shadow(color: Theme.accent.opacity(0.18), radius: 20, y: 16)
            .at(58, 248)
            .heroPop(shown, delay: 0.2)
        }
    }
}

/// Page 2: a mini case — complaint, question, test, then a graded result.
struct GradedHero: View {
    let shown: Bool

    var body: some View {
        HeroCanvas {
            UnevenRoundedRectangle(topLeadingRadius: 44, topTrailingRadius: 44, style: .continuous)
                .stroke(Theme.text.opacity(0.10), lineWidth: 3)
                .fill(LinearGradient(colors: [Theme.surface, Theme.surface.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(width: 322, height: 330)
                .at(14, 10)

            HStack(spacing: 12) {
                PatientAvatar(initials: "RM", size: 40, tint: .blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\u{201C}My chest feels tight.\u{201D}").font(.system(size: 16, weight: .semibold))
                    Text("Ray, 58 · Bed 3").font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(width: 310)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Theme.text.opacity(0.10), radius: 18, y: 12)
            .at(20, 54)
            .heroPop(shown, delay: 0)

            Text("When did it start?")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accentInk)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Theme.accent, in: UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20,
                                                                    bottomTrailingRadius: 6, topTrailingRadius: 20, style: .continuous))
                .shadow(color: Theme.accent.opacity(0.25), radius: 14, y: 10)
                .at(150, 140)
                .heroPop(shown, delay: 0.1)

            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.accent, lineWidth: 2).frame(width: 22, height: 22)
                Text("Order ECG and troponin").font(.system(size: 15))
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Theme.text.opacity(0.06), radius: 10, y: 8)
            .at(36, 206)
            .heroPop(shown, delay: 0.2)

            VStack(spacing: 2) {
                Text("CASE GRADE").font(.system(size: 13, weight: .semibold)).tracking(0.4).foregroundStyle(Theme.muted)
                Text("A\u{2212}").font(.system(size: 46, weight: .heavy)).foregroundStyle(Theme.accentText)
            }
            .frame(width: 206, height: 112)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Theme.text.opacity(0.14), radius: 22, y: 18)
            .at(72, 286)
            .heroPop(shown, delay: 0.32)

            HeroTag(text: "+ Asked onset", ink: Theme.accentText).at(8, 250).heroPop(shown, delay: 0.42)
            HeroTag(text: "Missed aspirin", ink: Theme.warnText).at(206, 364).heroPop(shown, delay: 0.48)
            Sparkle().fill(Theme.sparkleBlue).frame(width: 26, height: 44).at(296, 250).heroPop(shown, delay: 0.5)
            Sparkle().fill(Theme.sparkleMint).frame(width: 20, height: 20).at(24, 380).heroPop(shown, delay: 0.55)
        }
    }
}

/// Page 3: the promise — today's doubts become a doctor's steps.
struct PromiseHero: View {
    let shown: Bool
    private let steps = ["Right questions", "Tight differential", "Right test first", "Confident diagnosis"]

    var body: some View {
        HeroCanvas {
            Sparkle().fill(Theme.surface).frame(width: 26, height: 26).at(6, 8).heroPop(shown, delay: 0.5)
            Sparkle().fill(Theme.sparkleBlue).frame(width: 22, height: 36).at(318, 360).heroPop(shown, delay: 0.55)

            VStack(alignment: .leading, spacing: 8) {
                Text("TODAY").font(.system(size: 12, weight: .bold)).tracking(0.5).foregroundStyle(Theme.muted)
                doubt("Where do I start?").frame(maxWidth: .infinity, alignment: .leading)
                doubt("Which test?").frame(maxWidth: .infinity, alignment: .trailing)
                doubt("Is it the heart?").frame(maxWidth: .infinity, alignment: .leading)
                Text("? ? ?").font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity)
            }
            .padding(14)
            .frame(width: 150)
            .background(Theme.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Theme.text.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
            .rotationEffect(.degrees(-3))
            .at(4, 40)
            .heroPop(shown, delay: 0)

            CurvedArrow()
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                .frame(width: 64, height: 40)
                .at(140, 150)
                .heroPop(shown, delay: 0.15)

            VStack(alignment: .leading, spacing: 11) {
                Text("WITH ROUNDS").font(.system(size: 12, weight: .bold)).tracking(0.5).foregroundStyle(Theme.accentText)
                ForEach(steps, id: \.self) { step in
                    HStack(spacing: 10) {
                        CheckDot()
                        Text(step).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                    }
                }
            }
            .padding(16)
            .frame(width: 200, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Theme.accent.opacity(0.22), radius: 24, y: 20)
            .rotationEffect(.degrees(2))
            .at(140, 80)
            .heroPop(shown, delay: 0.25)

            VStack(spacing: 2) {
                AppIcon(.shieldCheck, size: 26).foregroundStyle(Theme.sparkleMint)
                Text("OUR\nPROMISE")
                    .font(.system(size: 13, weight: .heavy)).tracking(0.6)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.surface)
            }
            .frame(width: 112, height: 112)
            .background(Theme.text, in: Circle())
            .shadow(color: Theme.text.opacity(0.3), radius: 20, y: 16)
            .rotationEffect(.degrees(-6))
            .at(119, 290)
            .heroPop(shown, delay: 0.45)
        }
    }

    private func doubt(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.dim)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Theme.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .fixedSize()
    }
}

/// Hand-drawn style arrow from the "Today" card to the "With Rounds" card.
private struct CurvedArrow: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let sx = r.width / 64, sy = r.height / 40
        p.move(to: CGPoint(x: 4 * sx, y: 30 * sy))
        p.addCurve(to: CGPoint(x: 58 * sx, y: 18 * sy), control1: CGPoint(x: 20 * sx, y: 4 * sy), control2: CGPoint(x: 40 * sx, y: 4 * sy))
        p.move(to: CGPoint(x: 46 * sx, y: 14 * sy))
        p.addLine(to: CGPoint(x: 58 * sx, y: 18 * sy))
        p.addLine(to: CGPoint(x: 54 * sx, y: 30 * sy))
        return p
    }
}

/// Page 4: with vs. without Rounds, as an illustration (no real data yet, so it says so).
struct ExamReadyHero: View {
    let shown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HeroCanvas {
            Sparkle().fill(Theme.surface).frame(width: 26, height: 26).at(318, 14).heroPop(shown, delay: 0.6)
            Sparkle().fill(Theme.sparkleBlue).frame(width: 22, height: 36).at(320, 344).heroPop(shown, delay: 0.65)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Conditions practiced").font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text("Exam day")
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

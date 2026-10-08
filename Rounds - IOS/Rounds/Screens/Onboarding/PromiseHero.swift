import SwiftUI

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

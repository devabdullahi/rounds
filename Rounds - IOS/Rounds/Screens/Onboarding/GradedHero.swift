import SwiftUI

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

import SwiftUI

/// Page 1: a ring of fictional patients around "Diagnosis, nailed", with the patient count on top.
/// "1B+" is combinations, not clinically distinct cases: even the most limited stored profile
/// (≈216 presentations) times the generator's ≈600k names per age and sex clears 30 billion.
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

            // Last to land, after the ring: the scale behind the faces.
            HeroTag(text: "1B+ patient combos", ink: Theme.accentInk, fill: Theme.welcomeGreen)
                .accessibilityLabel("Over a billion patient combinations")
                .at(150, 0)
                .heroPop(shown, delay: 0.5)
        }
    }
}

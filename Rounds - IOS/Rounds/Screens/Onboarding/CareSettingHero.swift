import SwiftUI

/// "Where do you want to see patients?": Clinic, Hospital or Both as floating bubbles; one tap
/// picks. OSCE students arrive with Clinic already picked (set from their goal).
struct CareSettingHero: View {
    let shown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(CareSetting.storageKey) private var stored = ""

    /// Each choice's bubble label and spot on the 350×400 hero board, with the icon beside it.
    private static let choices: [(setting: CareSetting, label: String, spot: CGPoint, glyph: IconGlyph, glyphSpot: CGPoint)] = [
        (.clinic, "Clinic", CGPoint(x: 40, y: 70), .stethoscope, CGPoint(x: 230, y: 40)),
        (.hospital, "Hospital", CGPoint(x: 160, y: 170), .hospital, CGPoint(x: 40, y: 190)),
        (.any, "Both", CGPoint(x: 60, y: 280), .shuffle, CGPoint(x: 250, y: 290)),
    ]

    private var setting: CareSetting { CareSetting(stored: stored) }

    var body: some View {
        HeroCanvas {
            Ellipse().stroke(Theme.accent.opacity(0.14)).frame(width: 300, height: 220).at(24, 100)
            Sparkle().fill(Theme.sparkleMint).frame(width: 26, height: 44).at(310, 150)
            Sparkle().fill(Theme.sparkleBlue).frame(width: 20, height: 20).at(10, 360)
            ForEach(Array(Self.choices.enumerated()), id: \.offset) { i, c in
                IconPill(glyph: c.glyph).at(c.glyphSpot.x, c.glyphSpot.y).heroPop(shown, delay: 0.2 + Double(i) * 0.06)
            }
        }
        .overlay { bubbles }
    }

    private var bubbles: some View {
        GeometryReader { geo in
            let scale = HeroBoard.scale(in: geo.size)
            let origin = HeroBoard.origin(in: geo.size)
            ForEach(Array(Self.choices.enumerated()), id: \.offset) { i, c in
                ChoiceBubble(label: c.label, on: setting == c.setting) {
                    withAnimation(reduceMotion ? nil : Springs.pop) { stored = c.setting.rawValue }
                }
                .heroPop(shown, delay: Double(i) * 0.06)
                .offset(x: origin.x + c.spot.x * scale, y: origin.y + c.spot.y * scale)
            }
        }
    }
}

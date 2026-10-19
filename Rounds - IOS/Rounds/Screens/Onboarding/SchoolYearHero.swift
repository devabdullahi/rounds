import SwiftUI

/// "What year are you in?": MS1–MS4 as floating bubbles; one tap picks. Asked second, right after
/// the first promise page, so the student is answering by the second screen.
struct SchoolYearHero: View {
    let shown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(SchoolYear.storageKey) private var stored = ""

    /// Where each bubble floats on the 350×400 hero board.
    private static let spots: [SchoolYear: CGPoint] = [
        .ms1: CGPoint(x: 34, y: 46), .ms2: CGPoint(x: 196, y: 92),
        .ms3: CGPoint(x: 70, y: 196), .ms4: CGPoint(x: 208, y: 290),
    ]

    private var year: SchoolYear? { SchoolYear(stored: stored) }

    var body: some View {
        HeroCanvas {
            Ellipse().stroke(Theme.accent.opacity(0.14)).frame(width: 310, height: 200).at(16, 110)
            Ellipse().stroke(Theme.accent.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .frame(width: 230, height: 120).at(60, 150)
            Sparkle().fill(Theme.sparkleMint).frame(width: 26, height: 44).at(304, 60)
            Sparkle().fill(Theme.sparkleBlue).frame(width: 20, height: 20).at(18, 360)
            Sparkle().fill(Theme.sparkleBlue).frame(width: 14, height: 14).at(150, 20)
        }
        .overlay { bubbles }
    }

    /// The choices sit on the same scaled board as the art, but stay tappable and readable.
    private var bubbles: some View {
        GeometryReader { geo in
            let scale = HeroBoard.scale(in: geo.size)
            let origin = HeroBoard.origin(in: geo.size)
            ForEach(Array(SchoolYear.allCases.enumerated()), id: \.element) { i, y in
                let spot = Self.spots[y] ?? .zero
                // Pop first, then place, as on the study goal page.
                ChoiceBubble(label: y.label, on: year == y) {
                    withAnimation(reduceMotion ? nil : Springs.pop) { stored = y.rawValue }
                }
                .heroPop(shown, delay: Double(i) * 0.06)
                .offset(x: origin.x + spot.x * scale, y: origin.y + spot.y * scale)
            }
        }
    }
}

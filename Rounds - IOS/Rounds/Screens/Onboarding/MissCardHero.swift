import SwiftUI

/// "Learn from every miss": a graded miss on one side, the flashcard it becomes on the other. Tap
/// to flip, as many times as they like. Reduce Motion: the faces cross-fade instead of turning.
struct MissCardHero: View {
    let shown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flipped = false

    var body: some View {
        HeroCanvas {
            Sparkle().fill(Theme.sparkleMint).frame(width: 26, height: 44).at(310, 20).heroPop(shown, delay: 0.2)
            Sparkle().fill(Theme.sparkleBlue).frame(width: 20, height: 20).at(16, 360).heroPop(shown, delay: 0.24)
        }
        .overlay {
            VStack(spacing: 14) {
                Button {
                    withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.55, dampingFraction: 0.8)) {
                        flipped.toggle()
                    }
                } label: {
                    ZStack {
                        miss.opacity(flipped ? 0 : 1)
                        card.opacity(flipped ? 1 : 0)
                            .rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (0, 1, 0))
                    }
                    .rotation3DEffect(.degrees(flipped && !reduceMotion ? 180 : 0), axis: (0, 1, 0), perspective: 0.5)
                }
                .buttonStyle(PressDownStyle())
                .accessibilityLabel(flipped ? "Flashcard: First drug for a suspected heart attack? Aspirin, chewed."
                                            : "Missed on a case: aspirin for chest pain. Tap to see the flashcard.")
                .heroPop(shown, delay: 0)

                HStack(spacing: 6) {
                    AppIcon(.cards, size: 14)
                    Text(flipped ? "Made from your miss" : "Tap the card")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .heroPop(shown, delay: 0.12)
                .accessibilityHidden(true)
            }
        }
    }

    private var miss: some View {
        face(fill: Theme.surface) {
            Pill(text: "Missed", fg: Theme.warnText, bg: Theme.warnSoft, glyph: .triangleAlert)
            Text("Ray, 58 · chest pain").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.muted)
            Text("You didn't give aspirin.").font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.text)
        }
    }

    private var card: some View {
        face(fill: Theme.accent) {
            Text("FLASHCARD").font(.system(size: 12, weight: .bold)).tracking(1).foregroundStyle(Theme.accentInk.opacity(0.8))
            Text("First drug for a suspected heart attack?").font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.accentInk)
            Text("Aspirin, chewed.").font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.accentInk.opacity(0.9))
        }
    }

    private func face(fill: Color, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) { content() }
            .frame(width: 290, height: 200, alignment: .leading)
            .padding(.horizontal, 22)
            .background(fill, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: Theme.text.opacity(0.12), radius: 22, y: 14)
    }
}

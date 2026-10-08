import SwiftUI

/// Two-sided card: question on the front, answer on the back, turned on the Y axis.
struct CardFace: View {
    let card: Flashcard
    let flipped: Bool
    let glow: Color?
    var height: CGFloat = DECK.cardHeight
    var textSize: CGFloat = 24

    var body: some View {
        ZStack {
            side(text: card.front)
                .opacity(flipped ? 0 : 1)
            side(text: card.back)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(flipped ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(card.color.tint.opacity(card.color.wash))
                .allowsHitTesting(false)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(glow ?? (card.color == .standard ? Theme.ring : card.color.tint.opacity(0.45)),
                              lineWidth: glow == nil ? 1 : 2.5)
        )
        .shadow(color: (glow ?? .black).opacity(glow == nil ? 0.08 : 0.35), radius: glow == nil ? 10 : 16, y: 4)
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(flipped ? "Answer: \(card.back)" : "Question: \(card.front)")
        .accessibilityHint(flipped ? "" : "Double-tap to flip")
    }

    private func side(text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Text(text)
                .font(.system(size: textSize, weight: .semibold))
                .lineSpacing(3)
                .minimumScaleFactor(0.8)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

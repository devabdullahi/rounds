import SwiftUI

/// The + on Flashcards: write a card yourself, or have a deck generated for chosen topics.
struct AddCardsSheet: View {
    enum Choice { case write, generate }

    var onChoose: (Choice) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add cards")
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 24)
                .accessibilityAddTraits(.isHeader)
            row(.pencil, "Write a card", "Your own question and answer", highlighted: false) { choose(.write) }
            row(.cards, "Generate cards", "Pick topics and a count", highlighted: true) {
                choose(.generate)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .presentationDetents([.height(270)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.surface)
    }

    /// The parent opens the chosen sheet after this one finishes closing.
    private func choose(_ choice: Choice) {
        onChoose(choice)
        dismiss()
    }

    private func row(_ glyph: IconGlyph, _ title: String, _ detail: String, highlighted: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                AppIcon(glyph, size: 22)
                    .foregroundStyle(highlighted ? .white : Theme.accentText)
                    .frame(width: 44, height: 44)
                    .background(highlighted ? Theme.accent : Theme.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 17, weight: .semibold))
                    Text(detail).font(.system(size: 14)).foregroundStyle(Theme.muted).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                AppIcon(.chevronRight, size: 16).foregroundStyle(Theme.faint)
            }
            .foregroundStyle(Theme.text)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(highlighted ? Theme.accentSoft : Theme.track, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(highlighted ? Theme.accent.opacity(0.45) : Theme.ring))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}

import SwiftUI

/// A coach card in the chat that points at the next step ("Good history. Time to examine him."),
/// with one button that goes there. Inverted colors so it reads as a prompt, not a patient reply.
struct NudgeCard: View {
    let glyph: IconGlyph
    let title: String
    let detail: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AppIcon(glyph, size: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(detail)
                    .font(.system(size: 13))
                    .opacity(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: action) {
                Text(actionTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .glassCapsule(tint: Theme.accentFill)
            }
            .buttonStyle(PressDownStyle())
        }
        .foregroundStyle(Theme.bg)
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .background(Theme.text, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

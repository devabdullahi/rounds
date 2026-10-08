import SwiftUI

struct IconButton: View {
    let glyph: IconGlyph
    let label: String
    var size: CGFloat = 22
    /// Neutral glass for secondary navigation on screens whose primary action is already blue.
    var quiet = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            AppIcon(glyph, size: size * 0.8)
                .foregroundStyle(quiet ? Theme.text : .white)
                .frame(width: 38, height: 38)
                .glassCircle(tint: quiet ? Theme.text.opacity(0.10) : Theme.accent)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

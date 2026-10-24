import SwiftUI

/// One row of the debrief's "Go deeper" list: an icon, a title, an optional note on the right, and a
/// chevron that turns when the row opens its section underneath.
struct DebriefSectionRow: View {
    let glyph: IconGlyph
    let tint: Color
    let title: String
    var note: String?
    var noteTint: Color = Theme.muted
    let open: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AppIcon(glyph, size: 18)
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if let note {
                    Text(note)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(noteTint)
                }
                DisclosureChevron(open: open)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityValue(open ? "Open" : "Closed")
        .accessibilityHint(open ? "Hides this section" : "Shows this section")
    }
}

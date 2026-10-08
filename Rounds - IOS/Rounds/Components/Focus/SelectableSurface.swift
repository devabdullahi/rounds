import SwiftUI

/// The onboarding option look: surface card, accent ring and wash when picked.
struct SelectableSurface: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        content
            .background(on ? Theme.accent.opacity(0.10) : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(on ? Theme.accent : Theme.text.opacity(0.10), lineWidth: on ? 1.5 : 1)
            )
            .contentShape(Rectangle())
    }
}

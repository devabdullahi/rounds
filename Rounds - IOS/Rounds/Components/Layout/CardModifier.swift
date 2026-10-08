import SwiftUI

struct CardModifier: ViewModifier {
    var radius: CGFloat = 16
    var padding: CGFloat = 16
    var fillHeight = false
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: fillHeight ? .infinity : nil, alignment: .topLeading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.ring, lineWidth: 1))
    }
}

extension View {
    func card(radius: CGFloat = 16, padding: CGFloat = 16, fillHeight: Bool = false) -> some View {
        modifier(CardModifier(radius: radius, padding: padding, fillHeight: fillHeight))
    }

    /// Grouped list container: rows separated by hairlines.
    func listSurface() -> some View {
        self
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.ring, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

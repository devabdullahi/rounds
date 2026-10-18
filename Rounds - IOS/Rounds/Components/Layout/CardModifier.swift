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

    /// Grouped list container in Liquid Glass on iOS 26+, tinted with the surface colour so rows
    /// keep their contrast; `listSurface()` before. Non-interactive: pressing a row inside mustn't
    /// make the whole card swell.
    @ViewBuilder
    func glassListSurface() -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        if #available(iOS 26, *) {
            self
                .clipShape(shape)
                .glassEffect(.regular.tint(Theme.surface.opacity(0.55)), in: shape)
        } else {
            listSurface()
        }
    }
}

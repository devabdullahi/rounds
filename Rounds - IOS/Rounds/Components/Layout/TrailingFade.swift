import SwiftUI

/// Fades a horizontally scrolling row out at its trailing edge so it reads as scrollable.
struct TrailingFade: ViewModifier {
    var width: CGFloat = 28
    func body(content: Content) -> some View {
        content.mask(
            HStack(spacing: 0) {
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: width)
            }
        )
    }
}

extension View {
    func trailingFade(_ width: CGFloat = 28) -> some View { modifier(TrailingFade(width: width)) }
}

import SwiftUI

/// Google "G" mark, from the official four-color logo (Assets.xcassets/Icons/google).
/// Rendered as the original artwork: brand colors must not be tinted.
struct GoogleLogo: View {
    var size: CGFloat = 20

    var body: some View {
        Image("Icons/google")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

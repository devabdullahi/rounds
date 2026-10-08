import SwiftUI

struct AppIcon: View {
    let glyph: IconGlyph
    var size: CGFloat = 24

    init(_ glyph: IconGlyph, size: CGFloat = 24) {
        self.glyph = glyph
        self.size = size
    }

    var body: some View {
        Image(glyph.assetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

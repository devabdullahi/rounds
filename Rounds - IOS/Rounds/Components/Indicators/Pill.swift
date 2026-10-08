import SwiftUI

struct Pill: View {
    let text: String
    var fg: Color = Theme.accentText
    var bg: Color = Theme.accentSoft
    var glyph: IconGlyph? = nil
    var body: some View {
        HStack(spacing: 6) {
            if let glyph { AppIcon(glyph, size: 13) }
            Text(text)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(fg)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(bg, in: Capsule())
    }
}

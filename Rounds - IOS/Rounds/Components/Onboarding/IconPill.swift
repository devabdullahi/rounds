import SwiftUI

/// Small dark capsule holding one icon, floating in the hero art.
struct IconPill: View {
    let glyph: IconGlyph
    var body: some View {
        AppIcon(glyph, size: 20)
            .foregroundStyle(Theme.surface)
            .frame(width: 46, height: 40)
            .background(Theme.text, in: Capsule())
            .shadow(color: Theme.text.opacity(0.2), radius: 10, y: 6)
    }
}

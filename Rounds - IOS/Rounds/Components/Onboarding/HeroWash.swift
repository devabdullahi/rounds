import SwiftUI

/// Soft colour wash fading to the page colour, behind the hero art.
struct HeroWash: View {
    var tint: Color = Theme.heroMint
    var body: some View {
        LinearGradient(stops: [.init(color: tint, location: 0), .init(color: tint.opacity(0.45), location: 0.42),
                               .init(color: Theme.surface, location: 0.64)],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

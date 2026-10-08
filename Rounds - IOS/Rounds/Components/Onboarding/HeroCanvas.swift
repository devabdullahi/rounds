import SwiftUI

/// Decorative hero art drawn on the HeroBoard. Hidden from VoiceOver: the headline says it.
struct HeroCanvas<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) { content }
                .frame(width: HeroBoard.size.width, height: HeroBoard.size.height, alignment: .topLeading)
                .scaleEffect(HeroBoard.scale(in: geo.size))
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityHidden(true)
    }
}

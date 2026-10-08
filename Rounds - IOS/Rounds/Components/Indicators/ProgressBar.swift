import SwiftUI

struct ProgressBar: View {
    var value: Double
    var color: Color = Theme.accent
    var height: CGFloat = 8
    @State private var shown: Double = 0
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule().fill(color).frame(width: geo.size.width * min(max(shown, 0), 1))
            }
        }
        .frame(height: height)
        .onAppear { withAnimation(Springs.card.delay(0.15)) { shown = value } }
        .onChange(of: value) { _, new in withAnimation(Springs.card) { shown = new } }
    }
}

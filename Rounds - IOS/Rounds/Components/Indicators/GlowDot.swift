import SwiftUI

struct GlowDot: View {
    var color: Color
    var pulsing = true
    @State private var on = false
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .shadow(color: color, radius: on ? 6 : 2)
            .opacity(on ? 1 : 0.55)
            .onAppear {
                guard pulsing else { on = true; return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { on = true }
            }
    }
}

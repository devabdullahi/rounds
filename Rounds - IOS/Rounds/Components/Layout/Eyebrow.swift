import SwiftUI

struct Eyebrow: View {
    let text: String
    var color: Color = Theme.muted
    init(_ text: String, color: Color = Theme.muted) { self.text = text; self.color = color }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(color)
    }
}

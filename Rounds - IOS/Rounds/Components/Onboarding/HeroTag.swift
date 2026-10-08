import SwiftUI

/// White label bubble with a soft shadow.
struct HeroTag: View {
    let text: String
    var ink: Color = Theme.text
    var fill: Color = Theme.surface
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Theme.text.opacity(0.08), radius: 10, y: 6)
    }
}

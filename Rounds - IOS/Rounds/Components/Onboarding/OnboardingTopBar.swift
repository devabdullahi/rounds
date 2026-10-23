import SwiftUI

/// Back button plus a progress bar, filled to `current` of `total` (1-based).
struct OnboardingTopBar: View {
    let total: Int
    let current: Int
    var onBack: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            if let onBack {
                IconButton(glyph: .chevronLeft, label: "Back", quiet: true, action: onBack)
                    .padding(.leading, -3)   // circle edge on the page's 20pt margin (3pt inset in the hit box)
            }
            GeometryReader { geo in
                Capsule().fill(Theme.track)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Theme.accent)
                            .frame(width: geo.size.width * CGFloat(current) / CGFloat(max(total, 1)))
                    }
            }
            .frame(height: 6)
            .animation(.easeOut(duration: 0.3), value: current)
            .accessibilityElement()
            .accessibilityLabel("Step \(current) of \(total)")
        }
        .frame(height: 44)
    }
}

import SwiftUI

/// Back button plus a segmented progress bar, filled up to `current` (1-based).
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
            HStack(spacing: 6) {
                ForEach(1...total, id: \.self) { i in
                    Capsule()
                        .fill(i <= current ? Theme.text : Theme.control)
                        .frame(height: 4)
                }
            }
            .animation(.easeOut(duration: 0.25), value: current)
            .accessibilityElement()
            .accessibilityLabel("Step \(current) of \(total)")
        }
        .frame(height: 44)
    }
}

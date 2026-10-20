import SwiftUI

/// A floating pill answer on an onboarding hero: white when unpicked, accent with a check when picked.
struct ChoiceBubble: View {
    let label: String
    let on: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if on {
                    AppIcon(.check, size: 14)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 26, height: 26)
                        .background(Theme.surface, in: Circle())
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                }
                Text(label).font(.system(size: 19, weight: .semibold))
            }
            .foregroundStyle(on ? Theme.accentInk : Theme.text)
            .padding(.leading, on ? 14 : 22)
            .padding(.trailing, 22)
            .frame(height: 56)
            .background(on ? Theme.accent : Theme.surface, in: Capsule())
            .shadow(color: (on ? Theme.accent : Theme.text).opacity(on ? 0.32 : 0.10), radius: on ? 16 : 11, y: on ? 14 : 8)
            .scaleEffect(on && !reduceMotion ? 1.06 : 1)
        }
        .buttonStyle(PressDownStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

import SwiftUI

/// "Mix it up": the escape hatch, shared by onboarding and the sheet so it reads the same.
struct MixRow: View {
    let byRotation: Bool
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                AppIcon(.shuffle, size: 20).foregroundStyle(Theme.accentText)
                Text(byRotation ? "Between specialties · mix it up" : "Not sure · mix it up")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                if on { FocusCheck(size: 20) }
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 52)
            .modifier(SelectableSurface(on: on))
        }
        .buttonStyle(PressDownStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

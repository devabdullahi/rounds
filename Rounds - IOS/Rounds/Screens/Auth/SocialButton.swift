import SwiftUI

struct SocialButton: View {
    let provider: SocialProvider
    let title: String
    var height: CGFloat = 52
    let action: () -> Void

    private enum SOCIAL {
        static let icon: CGFloat = 20          // shared icon box so both marks read the same size
        static let iconInset: CGFloat = 20     // pinned icon's distance from the leading edge
        static let gap: CGFloat = 8            // icon ↔ label in compact buttons
    }

    /// Full-width buttons pin the icon to the leading edge and center the label, so stacked
    /// buttons share one icon column. Half-width buttons center icon + label together.
    private var pinsIcon: Bool { height >= 52 }

    var body: some View {
        Button(action: action) {
            ZStack {
                if pinsIcon {
                    HStack { icon; Spacer() }
                        .padding(.leading, SOCIAL.iconInset)
                    Text(title)
                } else {
                    HStack(spacing: SOCIAL.gap) { icon; Text(title) }
                }
            }
            .font(.system(size: pinsIcon ? 17 : 16, weight: .semibold))
            .foregroundStyle(provider == .apple ? Theme.bg : Theme.text)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(provider == .apple ? Theme.text : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                if provider == .google {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.border)
                }
            }
        }
        .buttonStyle(PressDownStyle())
    }

    @ViewBuilder
    private var icon: some View {
        switch provider {
        case .apple:
            // Apple's mark is required on Sign in with Apple and only ships as an SF Symbol.
            // The glyph sits low and small in its box; nudge it to match the G optically.
            Image(systemName: "apple.logo")
                .font(.system(size: 18, weight: .medium))
                .offset(y: -1)
                .frame(width: SOCIAL.icon, height: SOCIAL.icon)
        case .google:
            GoogleLogo(size: SOCIAL.icon - 2)   // the G's round shape reads larger than the Apple mark
                .frame(width: SOCIAL.icon, height: SOCIAL.icon)
        }
    }
}

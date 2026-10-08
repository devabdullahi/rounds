import SwiftUI

/// Chevron that rotates with its disclosure.
struct DisclosureChevron: View {
    let open: Bool
    var body: some View {
        AppIcon(.chevronDown, size: 18)
            .foregroundStyle(Theme.muted)
            .rotationEffect(.degrees(open ? DISCLOSURE.chevronOpen : 0))
            .animation(DISCLOSURE.open, value: open)
    }
}

import SwiftUI

/// Tab-screen large title (with optional trailing control). Shared by the tabs so titles sit at the same height.
struct ScreenTitle<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .tracking(-0.5)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            trailing
        }
    }
}

extension ScreenTitle where Trailing == EmptyView {
    init(title: String) { self.init(title: title) { EmptyView() } }
}

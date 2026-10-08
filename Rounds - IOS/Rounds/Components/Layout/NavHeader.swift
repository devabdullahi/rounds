import SwiftUI

struct NavHeader<Leading: View, Trailing: View>: View {
    let title: String
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing
    var body: some View {
        ZStack {
            // Title centers on the screen, not between the side controls: an empty side
            // (EmptyView) has no width and used to push the title off-center.
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 76)
            HStack {
                leading.frame(width: 64, alignment: .leading)
                Spacer()
                trailing.frame(width: 64, alignment: .trailing)
            }
            // A 22pt Phosphor caret in a 44pt hit box starts ~17pt in; 3pt lead puts its edge on the 20pt margin.
            .padding(.leading, 3)
            .padding(.trailing, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}

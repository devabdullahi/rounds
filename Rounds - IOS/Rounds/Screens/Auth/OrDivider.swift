import SwiftUI

struct OrDivider: View {
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Theme.text.opacity(0.10)).frame(height: 1)
            Text(text).font(.system(size: 13)).foregroundStyle(Theme.muted).fixedSize()
            Rectangle().fill(Theme.text.opacity(0.10)).frame(height: 1)
        }
    }
}

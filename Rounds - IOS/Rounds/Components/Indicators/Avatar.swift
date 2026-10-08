import SwiftUI

/// Initials in a circle, or the photo at `imageURL` once it loads (initials while loading or if it fails).
struct Avatar: View {
    let initials: String
    var size: CGFloat = 40
    var fg: Color = Theme.bg
    var bg: Color = Theme.text
    var imageURL: URL? = nil
    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.36, weight: .bold))
            .foregroundStyle(fg)
            .frame(width: size, height: size)
            .background(bg, in: Circle())
            .overlay {
                if let imageURL {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: { Color.clear }
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                }
            }
            .accessibilityHidden(true)
    }
}

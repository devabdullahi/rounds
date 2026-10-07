import UIKit

/// Prepares a picked photo for upload: a centred square, 512px, JPEG. Keeps uploads small (well
/// under the avatars bucket's 1 MB limit) and strips the original's metadata, such as location.
enum AvatarImage {
    static let side: CGFloat = 512

    static func jpeg(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        let crop = min(size.width, size.height)
        guard crop > 0 else { return nil }
        let scale = side / crop
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let square = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            let drawn = CGSize(width: size.width * scale, height: size.height * scale)
            image.draw(in: CGRect(x: (side - drawn.width) / 2, y: (side - drawn.height) / 2,
                                  width: drawn.width, height: drawn.height))
        }
        return square.jpegData(compressionQuality: 0.8)
    }
}

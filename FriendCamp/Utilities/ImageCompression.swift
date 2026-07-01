import UIKit

// Redimensionează la max 1600px pe latura lungă și comprimă JPEG — păstrează Storage-ul modest.
func compressedJPEGData(from image: UIImage, maxDimension: CGFloat = 1600, quality: CGFloat = 0.7) -> Data? {
    let size = image.size
    let scale = min(1, maxDimension / max(size.width, size.height))
    let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

    let renderer = UIGraphicsImageRenderer(size: targetSize)
    let resized = renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: targetSize))
    }
    return resized.jpegData(compressionQuality: quality)
}

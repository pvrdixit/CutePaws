
import ImageIO
import Foundation

struct MediaQualityEvaluator {

    static let minFileSize = 80_000
    static let maxFileSize = 1_000_000
    static let minTotalPixels: CGFloat = 400_000

    static let minAspectRatio: CGFloat = 0.5
    static let maxAspectRatio: CGFloat = 2.0

    static func isAcceptableImage(data: Data) -> Bool {

        // File size check
        guard data.count >= minFileSize,
              data.count <= maxFileSize else {
            return false
        }

        // Read metadata without full image decode
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
            let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
            height > 0
        else {
            return false
        }

        let totalPixels = width * height
        let aspectRatio = width / height

        guard totalPixels >= minTotalPixels else {
            return false
        }

        guard aspectRatio >= minAspectRatio,
              aspectRatio <= maxAspectRatio else {
            return false
        }

        return true
    }
}

import Foundation
import ImageIO

struct MediaQualityEvaluator {
    static let minFileSize = 80_000
    static let maxFileSize = 1_000_000
    static let minTotalPixels: CGFloat = 400_000

    static func isAcceptableImage(data: Data) -> Bool {
        guard data.count >= minFileSize, data.count <= maxFileSize else {
            return false
        }

        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
            let height = properties[kCGImagePropertyPixelHeight] as? CGFloat
        else {
            return false
        }

        return (width * height) >= minTotalPixels
    }
}

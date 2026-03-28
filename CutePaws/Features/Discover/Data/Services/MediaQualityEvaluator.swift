
import ImageIO
import Foundation

struct MediaQualityEvaluator {

    static let minFileSize = 80_000
    static let maxFileSize = 1_000_000
    static let minTotalPixels: CGFloat = 400_000

    static let minAspectRatio: CGFloat = 0.5
    static let maxAspectRatio: CGFloat = 2.0

    static let spotlightMinFileSize = 800_000
    static let spotlightMaxFileSize = 2_000_000
    static let miniMomentMinFileSize = 1_000_000
    static let miniMomentMaxFileSize = 8_000_000
    static let gifMinFileSize = 800_000
    static let gifMaxFileSize = 5_000_000

    static func isFileSizeWithinLimits(_ bytes: Int, min: Int, max: Int) -> Bool {
        bytes >= min && bytes <= max
    }

    static func isAcceptableSpotlightFileSize(_ bytes: Int) -> Bool {
        isFileSizeWithinLimits(bytes, min: spotlightMinFileSize, max: spotlightMaxFileSize)
    }

    static func isAcceptableMiniMomentFileSize(_ bytes: Int) -> Bool {
        isFileSizeWithinLimits(bytes, min: miniMomentMinFileSize, max: miniMomentMaxFileSize)
    }

    static func isAcceptableGifFileSize(_ bytes: Int) -> Bool {
        isFileSizeWithinLimits(bytes, min: gifMinFileSize, max: gifMaxFileSize)
    }

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

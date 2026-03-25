import Foundation
import ImageIO

protocol ImageMetadataService {
    func aspectRatio(from data: Data) -> Double?
}

final class DefaultImageMetadataService: ImageMetadataService {
    func aspectRatio(from data: Data) -> Double? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
            let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
            height > 0
        else {
            return nil
        }

        return Double(width / height)
    }
}

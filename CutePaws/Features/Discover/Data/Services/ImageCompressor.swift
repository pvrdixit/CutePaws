import Foundation
import ImageIO

/// JPEG downscale + recompression (e.g. breed thumbnails in SwiftData).
struct ImageCompressor: Sendable {
    private let maxPixelDimension: Int
    private let maxOutputBytes: Int
    private let compressionQualities: [CGFloat]

    init(
        maxPixelDimension: Int = 256,
        maxOutputBytes: Int = 120_000,
        compressionQualities: [CGFloat] = [0.82, 0.68, 0.55, 0.42]
    ) {
        self.maxPixelDimension = maxPixelDimension
        self.maxOutputBytes = maxOutputBytes
        self.compressionQualities = compressionQualities
    }

    nonisolated func compressedJPEGData(from downloadedData: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(downloadedData as CFData, nil) else {
            return nil
        }

        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
            return nil
        }

        var best: Data?
        for quality in compressionQualities {
            let out = NSMutableData()
            guard let dest = CGImageDestinationCreateWithData(
                out,
                "public.jpeg" as CFString,
                1,
                nil
            ) else {
                continue
            }

            let props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
            CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
            guard CGImageDestinationFinalize(dest) else { continue }

            let data = out as Data
            best = data
            if data.count <= maxOutputBytes {
                return data
            }
        }

        return best
    }
}

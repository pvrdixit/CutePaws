import Foundation
import ImageIO

/// Per-flow thresholds. Any field left `nil` is not checked.
struct MediaQualityCriteria: Equatable, Sendable {
    var downloadedByteLength: ClosedRange<Int>?
    var maxDownloadedBytes: Int?
    var minTotalPixels: CGFloat?
    var aspectRatio: ClosedRange<CGFloat>?
    var remoteReportedFileBytes: ClosedRange<Int>?

    init(
        downloadedByteLength: ClosedRange<Int>? = nil,
        maxDownloadedBytes: Int? = nil,
        minTotalPixels: CGFloat? = nil,
        aspectRatio: ClosedRange<CGFloat>? = nil,
        remoteReportedFileBytes: ClosedRange<Int>? = nil
    ) {
        self.downloadedByteLength = downloadedByteLength
        self.maxDownloadedBytes = maxDownloadedBytes
        self.minTotalPixels = minTotalPixels
        self.aspectRatio = aspectRatio
        self.remoteReportedFileBytes = remoteReportedFileBytes
    }
}

/// One policy per instance, driven by ``MediaQualityCriteria``.
struct MediaQualityEvaluator: Sendable {
    private let criteria: MediaQualityCriteria

    init(criteria: MediaQualityCriteria) {
        self.criteria = criteria
    }

    func passesDownloadedPayload(_ data: Data) -> Bool {
        if let maxB = criteria.maxDownloadedBytes, data.count > maxB {
            return false
        }
        if let range = criteria.downloadedByteLength, !range.contains(data.count) {
            return false
        }

        let needsDimensions = criteria.minTotalPixels != nil || criteria.aspectRatio != nil
        let dimensions: (width: CGFloat, height: CGFloat)?
        if needsDimensions {
            dimensions = Self.pixelDimensions(for: data)
        } else {
            dimensions = nil
        }

        if let minPx = criteria.minTotalPixels {
            guard let dims = dimensions, dims.height > 0 else { return false }
            guard dims.width * dims.height >= minPx else { return false }
        }

        if let arRange = criteria.aspectRatio {
            guard let dims = dimensions, dims.height > 0 else { return false }
            let ratio = dims.width / dims.height
            guard arRange.contains(ratio) else { return false }
        }

        return true
    }

    func passesRemoteReportedFileSize(_ bytes: Int) -> Bool {
        guard let range = criteria.remoteReportedFileBytes else {
            return true
        }
        return range.contains(bytes)
    }

    private static func pixelDimensions(for data: Data) -> (width: CGFloat, height: CGFloat)? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
            let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
            height > 0
        else {
            return nil
        }
        return (width, height)
    }
}

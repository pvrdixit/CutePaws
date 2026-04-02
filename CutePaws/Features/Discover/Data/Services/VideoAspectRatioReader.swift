import AVFoundation
import Foundation

enum VideoAspectRatioReader {
    actor VideoAspectRatioCache {
        private var storage: [String: CGFloat] = [:]
        func value(forKey key: String) -> CGFloat? { storage[key] }
        func set(_ value: CGFloat, forKey key: String) { storage[key] = value }
    }

    static let railMinAspectRatio: CGFloat = 0.56
    static let railMaxAspectRatio: CGFloat = 1.78

    private static let videoCache = VideoAspectRatioCache()

    static func isAcceptableRailAspectRatio(_ ratio: CGFloat) -> Bool {
        ratio >= railMinAspectRatio && ratio <= railMaxAspectRatio
    }

    static let railFallbackAspectRatio: CGFloat = 0.96

    static func videoAspectRatio(fileURL: URL) async -> CGFloat? {
        let key = fileURL.path
        if let cached = await videoCache.value(forKey: key) {
            return cached
        }

        let asset = AVURLAsset(url: fileURL)
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let track = tracks.first else { return nil }
            async let naturalSize = track.load(.naturalSize)
            async let preferredTransform = track.load(.preferredTransform)
            let size = try await naturalSize
            let transform = try await preferredTransform
            let transformedSize = size.applying(transform)
            let width = abs(transformedSize.width)
            let height = abs(transformedSize.height)
            guard width > 0, height > 0 else { return nil }
            let ratio = width / height
            await videoCache.set(ratio, forKey: key)
            return ratio
        } catch {
            return nil
        }
    }

    static func videoDisplayAspectRatio(localPath: String?) async -> CGFloat {
        guard let path = localPath else { return railFallbackAspectRatio }
        return await videoAspectRatio(fileURL: URL(fileURLWithPath: path)) ?? railFallbackAspectRatio
    }
}

import Foundation

/// Bundled `DogPreviewVideo.mp4` shown on the Discover rail until at least one mini moment is cached.
enum MiniMomentsPreviewVideo {
    private static let sentinelURL = URL(string: "cutePaws://discover/miniMoments/preview")!

    static var bundledFileURL: URL? {
        Bundle.main.url(forResource: "DogPreviewVideo", withExtension: "mp4")
    }

    static var placeholderItem: MiniMomentItem? {
        guard let url = bundledFileURL else { return nil }
        return MiniMomentItem(
            remoteURL: sentinelURL,
            localFilePath: url.path,
            fileSizeBytes: 0,
            createdAt: Date(),
            aspectRatio: nil
        )
    }

    static func matches(_ item: MiniMomentItem) -> Bool {
        item.remoteURL == sentinelURL
    }
}

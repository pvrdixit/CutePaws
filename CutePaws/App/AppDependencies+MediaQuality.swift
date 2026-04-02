import Foundation

extension AppDependencies {
    /// Named media-quality presets. Each is a ``MediaQualityEvaluator``.
    enum MediaQuality {
        static let dailyPicksQuality = MediaQualityEvaluator(
            criteria: MediaQualityCriteria(
                downloadedByteLength: 80_000...2_000_000,
                minTotalPixels: 400_000,
                aspectRatio: 0.5...2.0
            )
        )
        
        static let breedImagesQuality = MediaQualityEvaluator(
            criteria: MediaQualityCriteria(
                downloadedByteLength: 40_000...2_000_000,
                minTotalPixels: 150_000,
                aspectRatio: 0.5...2.0
            )
        )

        static let spotlight = MediaQualityEvaluator(
            criteria: MediaQualityCriteria(
                aspectRatio: 0.5...2.0,
                remoteReportedFileBytes: 800_000...2_000_000
            )
        )

        static let miniMoments = MediaQualityEvaluator(
            criteria: MediaQualityCriteria(
                remoteReportedFileBytes: 1_000_000...8_000_000
            )
        )

        static let breedThumbnail = MediaQualityEvaluator(
            criteria: MediaQualityCriteria(
                maxDownloadedBytes: 15_000_000,
                aspectRatio: 0.8...1.2
            )
        )
    }
}

import Foundation
import SwiftData

extension AppDependencies {
    private enum DiscoverLimits {
        static let dailyPicksVisibleCount = 20
        static let dailyPicksImageLimit = 100
        static let spotlightImageLimit = 10
        static let miniMomentsImageLimit = 10
        static let gifsImageLimit = 10
    }

    func makeDiscoverViewModel() -> DiscoverViewModel {
        let initialItems = discoverStore.fetchItemsSnapshot(limit: DiscoverLimits.dailyPicksVisibleCount)
        let initialSpotlightItem = spotlightStore.fetchItemsSnapshot(limit: DiscoverLimits.spotlightImageLimit).last
        let initialMiniMoments = miniMomentStore.fetchItemsSnapshot(limit: DiscoverLimits.miniMomentsImageLimit)
        let initialGifs = animatedGifStore.fetchItemsSnapshot(limit: DiscoverLimits.gifsImageLimit)

        #if DEBUG
        print("AppDependencies.makeDiscoverViewModel initialItems:", initialItems.count)
        #endif

        return DiscoverViewModel(
            repository: discoverRepository,
            spotlightRepository: spotlightRepository,
            miniMomentRepository: miniMomentRepository,
            animatedGifRepository: animatedGifRepository,
            favoriteRepository: favoriteRepository,
            initialItems: initialItems,
            initialSpotlightImagePath: initialSpotlightItem?.localFilePath,
            initialSpotlightAspectRatio: initialSpotlightItem?.aspectRatio,
            initialMiniMoments: initialMiniMoments,
            initialGifs: initialGifs,
            dailyPicksVisibleCount: DiscoverLimits.dailyPicksVisibleCount,
            dailyPicksImageLimit: DiscoverLimits.dailyPicksImageLimit,
            spotlightImageLimit: DiscoverLimits.spotlightImageLimit,
            miniMomentsImageLimit: DiscoverLimits.miniMomentsImageLimit,
            gifsImageLimit: DiscoverLimits.gifsImageLimit
        )
    }

    static func makeApplicationSupportDirectory(using fileManager: FileManager) throws -> URL {
        let directoryURL = try fileManager
            .url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            .appendingPathComponent("CutePaws", isDirectory: true)

        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return directoryURL
    }
}


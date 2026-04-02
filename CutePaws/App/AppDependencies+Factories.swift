import Foundation

extension AppDependencies {
    private enum DiscoverLimits {
        static let dailyPicksVisibleCount = 25
        static let dailyPicksImageLimit = 125
        static let spotlightImageLimit = 10
        static let miniMomentsStoreLimit = 50
        static let miniMomentsRailVisibleLimit = 10
    }

    func makeDiscoverViewModel() -> DiscoverViewModel {
        let initialItems = discoverStore.fetchItemsSnapshot(limit: DiscoverLimits.dailyPicksVisibleCount)
        let initialSpotlightItem = spotlightStore.fetchItemsSnapshot(limit: DiscoverLimits.spotlightImageLimit).last
        let initialMiniMoments = miniMomentStore.fetchItemsSnapshot(limit: DiscoverLimits.miniMomentsStoreLimit)

        #if DEBUG
        print("AppDependencies.makeDiscoverViewModel initialItems:", initialItems.count)
        #endif

        return DiscoverViewModel(
            repository: discoverRepository,
            spotlightRepository: spotlightRepository,
            miniMomentRepository: miniMomentRepository,
            breedGalleryRepository: breedGalleryRepository,
            favoriteRepository: favoriteRepository,
            initialItems: initialItems,
            initialSpotlightImagePath: initialSpotlightItem?.localFilePath,
            initialSpotlightAspectRatio: initialSpotlightItem?.aspectRatio,
            initialMiniMoments: initialMiniMoments,
            dailyPicksVisibleCount: DiscoverLimits.dailyPicksVisibleCount,
            dailyPicksImageLimit: DiscoverLimits.dailyPicksImageLimit,
            spotlightImageLimit: DiscoverLimits.spotlightImageLimit,
            miniMomentsStoreLimit: DiscoverLimits.miniMomentsStoreLimit,
            miniMomentsRailVisibleLimit: DiscoverLimits.miniMomentsRailVisibleLimit,
            userDefaults: .standard,
            calendar: .current
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

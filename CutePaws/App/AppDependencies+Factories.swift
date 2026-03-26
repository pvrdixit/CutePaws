import Foundation
import SwiftData

extension AppDependencies {
    private enum DiscoverLimits {
        static let dailyPicksVisibleCount = 20
        static let dailyPicksImageLimit = 20
        static let spotlightImageLimit = 5
    }

    func makeDiscoverViewModel() -> DiscoverViewModel {
        let initialItems = discoverStore.fetchItemsSnapshot(limit: DiscoverLimits.dailyPicksVisibleCount)
        let initialSpotlightItem = spotlightStore.fetchItemsSnapshot(limit: DiscoverLimits.spotlightImageLimit).last

        #if DEBUG
        print("AppDependencies.makeDiscoverViewModel initialItems:", initialItems.count)
        #endif

        return DiscoverViewModel(
            repository: discoverRepository,
            spotlightRepository: spotlightRepository,
            initialItems: initialItems,
            initialSpotlightImagePath: initialSpotlightItem?.localFilePath,
            initialSpotlightAspectRatio: initialSpotlightItem?.aspectRatio,
            dailyPicksVisibleCount: DiscoverLimits.dailyPicksVisibleCount,
            dailyPicksImageLimit: DiscoverLimits.dailyPicksImageLimit,
            spotlightImageLimit: DiscoverLimits.spotlightImageLimit
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


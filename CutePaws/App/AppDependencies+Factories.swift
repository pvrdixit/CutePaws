import Foundation
import SwiftData

extension AppDependencies {
    func makeDiscoverViewModel() -> DiscoverViewModel {
        let initialItems = discoverStore.fetchItemsSnapshot(limit: 20)
        let initialSpotlightItem = spotlightStore.fetchItemsSnapshot(limit: 1).first

        #if DEBUG
        print("AppDependencies.makeDiscoverViewModel initialItems:", initialItems.count)
        #endif

        return DiscoverViewModel(
            repository: discoverRepository,
            spotlightRepository: spotlightRepository,
            initialItems: initialItems,
            initialSpotlightImagePath: initialSpotlightItem?.localFilePath,
            initialSpotlightAspectRatio: initialSpotlightItem?.aspectRatio,
            visibleItemCount: 20
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


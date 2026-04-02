import Foundation
import SwiftData

extension AppDependencies {
    /// Builds isolated SwiftData stores under Application Support.
    struct ModelContainers {
        let discover: ModelContainer
        let spotlight: ModelContainer
        let miniMoments: ModelContainer
        let breedGallery: ModelContainer
        let favorites: ModelContainer
    }

    static func makeModelContainers(applicationSupportURL: URL) throws -> ModelContainers {
        let discoverStoreURL = applicationSupportURL.appendingPathComponent("discover.store")
        let discoverConfiguration = ModelConfiguration(url: discoverStoreURL, cloudKitDatabase: .none)
        let spotlightStoreURL = applicationSupportURL.appendingPathComponent("spotlight.store")
        let spotlightConfiguration = ModelConfiguration(url: spotlightStoreURL, cloudKitDatabase: .none)
        let miniMomentsStoreURL = applicationSupportURL.appendingPathComponent("miniMoments.store")
        let miniMomentsConfiguration = ModelConfiguration(url: miniMomentsStoreURL, cloudKitDatabase: .none)
        let breedGalleryStoreURL = applicationSupportURL.appendingPathComponent("breedGallery.store")
        let breedGalleryConfiguration = ModelConfiguration(url: breedGalleryStoreURL, cloudKitDatabase: .none)
        let favoritesStoreURL = applicationSupportURL.appendingPathComponent("favorites.store")
        let favoritesConfiguration = ModelConfiguration(url: favoritesStoreURL, cloudKitDatabase: .none)

        #if DEBUG
        print("SwiftData discover store path:", discoverStoreURL.path)
        print("SwiftData spotlight store path:", spotlightStoreURL.path)
        print("SwiftData mini moments store path:", miniMomentsStoreURL.path)
        print("SwiftData breed gallery store path:", breedGalleryStoreURL.path)
        print("SwiftData favorites store path:", favoritesStoreURL.path)
        #endif

        let discover = try ModelContainer(
            for: StoredMediaItem.self,
            configurations: discoverConfiguration
        )
        let spotlight = try ModelContainer(
            for: StoredSpotlightItem.self,
            configurations: spotlightConfiguration
        )
        let miniMoments = try ModelContainer(
            for: StoredMiniMomentItem.self,
            configurations: miniMomentsConfiguration
        )
        let breedGallery = try ModelContainer(
            for: StoredBreedGalleryItem.self,
            StoredBreedThumbnailItem.self,
            StoredBreedExploreMetadata.self,
            StoredBreedExploreGalleryImage.self,
            configurations: breedGalleryConfiguration
        )
        let favorites = try ModelContainer(
            for: StoredFavoriteItem.self,
            configurations: favoritesConfiguration
        )

        return ModelContainers(
            discover: discover,
            spotlight: spotlight,
            miniMoments: miniMoments,
            breedGallery: breedGallery,
            favorites: favorites
        )
    }
}

import Foundation
import SwiftData

@MainActor
final class AppDependencies {
    let logger: AppLogger
    let httpUtility: HTTPUtility
    let discoverModelContainer: ModelContainer
    let spotlightModelContainer: ModelContainer
    let miniMomentsModelContainer: ModelContainer
    let breedGalleryModelContainer: ModelContainer
    let favoritesModelContainer: ModelContainer

    init() {
        logger = AppLogger(subsystem: Bundle.main.bundleIdentifier ?? "CutePaws")
        httpUtility = HTTPUtility(timeout: 120.0)

        do {
            let applicationSupportURL = try Self.makeApplicationSupportDirectory(using: .default)
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

            discoverModelContainer = try ModelContainer(
                for: StoredMediaItem.self,
                configurations: discoverConfiguration
            )
            spotlightModelContainer = try ModelContainer(
                for: StoredSpotlightItem.self,
                configurations: spotlightConfiguration
            )
            miniMomentsModelContainer = try ModelContainer(
                for: StoredMiniMomentItem.self,
                configurations: miniMomentsConfiguration
            )
            breedGalleryModelContainer = try ModelContainer(
                for: StoredBreedGalleryItem.self,
                StoredBreedThumbnailItem.self,
                StoredBreedExploreMetadata.self,
                StoredBreedExploreGalleryImage.self,
                configurations: breedGalleryConfiguration
            )
            favoritesModelContainer = try ModelContainer(
                for: StoredFavoriteItem.self,
                configurations: favoritesConfiguration
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    lazy var discoverStore = SwiftDataDiscoverStore(
        container: discoverModelContainer,
        fileStorage: mediaFileStorage,
        logger: logger
    )
    lazy var spotlightStore = SwiftDataSpotlightStore(
        container: spotlightModelContainer,
        fileStorage: spotlightMediaFileStorage,
        logger: logger
    )
    lazy var miniMomentStore = SwiftDataMiniMomentStore(
        container: miniMomentsModelContainer,
        fileStorage: miniMomentMediaFileStorage,
        logger: logger
    )
    lazy var breedGalleryStore = SwiftDataBreedGalleryStore(
        container: breedGalleryModelContainer,
        fileStorage: breedGalleryMediaFileStorage,
        logger: logger
    )
    lazy var breedExploreGalleryStore = SwiftDataBreedExploreGalleryStore(
        container: breedGalleryModelContainer,
        fileStorage: breedExploreGalleryMediaFileStorage,
        logger: logger
    )
    lazy var breedThumbnailStore = SwiftDataBreedThumbnailStore(
        container: breedGalleryModelContainer,
        logger: logger
    )
    lazy var breedCatalogStore = SwiftDataBreedCatalogStore(
        container: breedGalleryModelContainer,
        logger: logger
    )
    lazy var favoriteStore = SwiftDataFavoriteStore(
        container: favoritesModelContainer,
        fileStorage: favoritesMediaFileStorage
    )

    private lazy var imageDownloadService = ImageDownloadService(httpUtility: httpUtility)
    private lazy var imageMetadataService: ImageMetadataService = DefaultImageMetadataService()
    private lazy var thumbnailCompressor = ImageCompressor()
    private lazy var mediaFileStorage: MediaFileStorage = DefaultMediaFileStorage(directoryName: "DailyPicks")
    private lazy var spotlightMediaFileStorage: MediaFileStorage = DefaultMediaFileStorage(directoryName: "SpotlightMedia")
    private lazy var miniMomentMediaFileStorage: MediaFileStorage = DefaultMediaFileStorage(directoryName: "MiniMoments")
    private lazy var breedGalleryMediaFileStorage: MediaFileStorage = DefaultMediaFileStorage(directoryName: "BreedGallery")
    private lazy var breedExploreGalleryMediaFileStorage: MediaFileStorage = DefaultMediaFileStorage(directoryName: "BreedExploreGallery")
    private lazy var favoritesMediaFileStorage: MediaFileStorage = DefaultMediaFileStorage(directoryName: "Favorites")
    private lazy var dogCeoRemoteDataSource = DogCeoRemoteDataSource(httpUtility: httpUtility)
    private lazy var dogCeoBreedGalleryRemoteDataSource = DogCeoBreedGalleryRemoteDataSource(httpUtility: httpUtility)
    private lazy var randomDogRemoteDataSource = RandomDogRemoteDataSource(
        httpUtility: httpUtility,
        mediaQualityEvaluator: MediaQuality.spotlight
    )
    private lazy var randomDogMiniMomentRemoteDataSource = RandomDogMiniMomentRemoteDataSource(
        httpUtility: httpUtility,
        mediaQualityEvaluator: MediaQuality.miniMoments
    )

    lazy var discoverRepository: DiscoverRepository = DiscoverRepositoryImpl(
        remoteDataSource: dogCeoRemoteDataSource,
        imageDownloadService: imageDownloadService,
        imageMetadataService: imageMetadataService,
        dailyPicksQuality: MediaQuality.dailyPicksQuality,
        mediaFileStorage: mediaFileStorage,
        store: discoverStore,
        logger: logger
    )
    
    lazy var spotlightRepository: SpotlightRepository = SpotlightRepositoryImpl(
        remoteDataSource: randomDogRemoteDataSource,
        imageDownloadService: imageDownloadService,
        imageMetadataService: imageMetadataService,
        mediaQualityEvaluator: MediaQuality.spotlight,
        mediaFileStorage: spotlightMediaFileStorage,
        store: spotlightStore,
        logger: logger
    )
    lazy var miniMomentRepository: MiniMomentRepository = MiniMomentRepositoryImpl(
        remoteDataSource: randomDogMiniMomentRemoteDataSource,
        imageDownloadService: imageDownloadService,
        mediaFileStorage: miniMomentMediaFileStorage,
        store: miniMomentStore,
        logger: logger
    )

    lazy var breedGalleryRepository: BreedGalleryRepository = BreedGalleryRepositoryImpl(
        remoteDataSource: dogCeoBreedGalleryRemoteDataSource,
        imageDownloadService: imageDownloadService,
        imageMetadataService: imageMetadataService,
        breedImagesQuality: MediaQuality.breedImagesQuality,
        breedThumbnailQuality: MediaQuality.breedThumbnail,
        thumbnailCompressor: thumbnailCompressor,
        exploreGalleryFileStorage: breedExploreGalleryMediaFileStorage,
        galleryStore: breedGalleryStore,
        exploreGalleryStore: breedExploreGalleryStore,
        thumbnailStore: breedThumbnailStore,
        catalogStore: breedCatalogStore,
        logger: logger
    )

    lazy var favoriteRepository: FavoriteRepository = FavoriteRepositoryImpl(
        store: favoriteStore,
        mediaFileStorage: favoritesMediaFileStorage
    )
}

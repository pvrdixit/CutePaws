import Foundation
import SwiftData

@MainActor
final class AppDependencies {
    let logger: AppLogger
    let httpUtility: HTTPUtility
    let discoverModelContainer: ModelContainer
    let spotlightModelContainer: ModelContainer
    let miniMomentsModelContainer: ModelContainer
    let gifsModelContainer: ModelContainer
    let favoritesModelContainer: ModelContainer

    init() {
        logger = AppLogger(subsystem: Bundle.main.bundleIdentifier ?? "CutePaws")
        httpUtility = HTTPUtility(timeout: 120.0)

        do {
            let applicationSupportURL = try Self.makeApplicationSupportDirectory(using: .default)
            let discoverStoreURL = applicationSupportURL.appendingPathComponent("discover.store")
            let discoverConfiguration = ModelConfiguration(url: discoverStoreURL)
            let spotlightStoreURL = applicationSupportURL.appendingPathComponent("spotlight.store")
            let spotlightConfiguration = ModelConfiguration(url: spotlightStoreURL)
            let miniMomentsStoreURL = applicationSupportURL.appendingPathComponent("miniMoments.store")
            let miniMomentsConfiguration = ModelConfiguration(url: miniMomentsStoreURL)
            let gifsStoreURL = applicationSupportURL.appendingPathComponent("gifs.store")
            let gifsConfiguration = ModelConfiguration(url: gifsStoreURL)
            let favoritesStoreURL = applicationSupportURL.appendingPathComponent("favorites.store")
            let favoritesConfiguration = ModelConfiguration(url: favoritesStoreURL)

            #if DEBUG
            print("SwiftData discover store path:", discoverStoreURL.path)
            print("SwiftData spotlight store path:", spotlightStoreURL.path)
            print("SwiftData mini moments store path:", miniMomentsStoreURL.path)
            print("SwiftData gifs store path:", gifsStoreURL.path)
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
            gifsModelContainer = try ModelContainer(
                for: StoredAnimatedGifItem.self,
                configurations: gifsConfiguration
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
    lazy var animatedGifStore = SwiftDataAnimatedGifStore(
        container: gifsModelContainer,
        fileStorage: gifMediaFileStorage,
        logger: logger
    )
    lazy var favoriteStore = SwiftDataFavoriteStore(
        container: favoritesModelContainer,
        fileStorage: favoritesMediaFileStorage
    )

    private lazy var imageDownloadService = ImageDownloadService(httpUtility: httpUtility)
    private lazy var imageMetadataService: ImageMetadataService = DefaultImageMetadataService()
    private lazy var mediaFileStorage: MediaFileStorage = DefaultMediaFileStorage(directoryName: "DailyPicks")
    private lazy var spotlightMediaFileStorage: MediaFileStorage = DefaultMediaFileStorage(directoryName: "SpotlightMedia")
    private lazy var miniMomentMediaFileStorage: MediaFileStorage = DefaultMediaFileStorage(directoryName: "MiniMoments")
    private lazy var gifMediaFileStorage: MediaFileStorage = DefaultMediaFileStorage(directoryName: "Gifs")
    private lazy var favoritesMediaFileStorage: MediaFileStorage = DefaultMediaFileStorage(directoryName: "Favorites")
    private lazy var dogCeoRemoteDataSource = DogCeoRemoteDataSource(httpUtility: httpUtility)
    private lazy var randomDogRemoteDataSource = RandomDogRemoteDataSource(httpUtility: httpUtility)
    private lazy var randomDogMiniMomentRemoteDataSource = RandomDogMiniMomentRemoteDataSource(httpUtility: httpUtility)
    private lazy var randomDogGifRemoteDataSource = RandomDogGifRemoteDataSource(httpUtility: httpUtility)

    lazy var discoverRepository: DiscoverRepository = DiscoverRepositoryImpl(
        remoteDataSource: dogCeoRemoteDataSource,
        imageDownloadService: imageDownloadService,
        imageMetadataService: imageMetadataService,
        mediaFileStorage: mediaFileStorage,
        store: discoverStore,
        logger: logger
    )
    
    lazy var spotlightRepository: SpotlightRepository = SpotlightRepositoryImpl(
        remoteDataSource: randomDogRemoteDataSource,
        imageDownloadService: imageDownloadService,
        imageMetadataService: imageMetadataService,
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
    lazy var animatedGifRepository: AnimatedGifRepository = AnimatedGifRepositoryImpl(
        remoteDataSource: randomDogGifRemoteDataSource,
        imageDownloadService: imageDownloadService,
        mediaFileStorage: gifMediaFileStorage,
        store: animatedGifStore,
        logger: logger
    )

    lazy var favoriteRepository: FavoriteRepository = FavoriteRepositoryImpl(
        store: favoriteStore,
        mediaFileStorage: favoritesMediaFileStorage
    )
}

import Foundation
import SwiftData

@MainActor
final class AppDependencies {
    let logger: AppLogger
    /// JSON + image bytes for Dog CEO–backed flows (tighter session timeouts).
    let dogCeoHTTPUtility: HTTPUtility
    /// RandomDog API (spotlight / mini moments) — longer waits for slow responses.
    let randomDogHTTPUtility: HTTPUtility
    let discoverModelContainer: ModelContainer
    let spotlightModelContainer: ModelContainer
    let miniMomentsModelContainer: ModelContainer
    let breedGalleryModelContainer: ModelContainer
    let favoritesModelContainer: ModelContainer

    init() {
        logger = AppLogger(subsystem: Bundle.main.bundleIdentifier ?? "CutePaws")
        dogCeoHTTPUtility = HTTPUtility(timeout: 20.0)
        randomDogHTTPUtility = HTTPUtility(timeout: 120.0)

        do {
            let applicationSupportURL = try Self.makeApplicationSupportDirectory(using: .default)
            let containers = try AppDependencies.makeModelContainers(applicationSupportURL: applicationSupportURL)
            discoverModelContainer = containers.discover
            spotlightModelContainer = containers.spotlight
            miniMomentsModelContainer = containers.miniMoments
            breedGalleryModelContainer = containers.breedGallery
            favoritesModelContainer = containers.favorites
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

    private lazy var imageDownloadService = ImageDownloadService(httpUtility: dogCeoHTTPUtility)
    private lazy var imageMetadataService: ImageMetadataService = DefaultImageMetadataService()
    private lazy var thumbnailCompressor = ImageCompressor()
    private lazy var mediaFileStorage: MediaFileStorage = DefaultMediaFileStorage(directoryName: "DailyPicks")
    private lazy var spotlightMediaFileStorage: MediaFileStorage = DefaultMediaFileStorage(directoryName: "SpotlightMedia")
    private lazy var miniMomentMediaFileStorage: MediaFileStorage = DefaultMediaFileStorage(directoryName: "MiniMoments")
    private lazy var breedGalleryMediaFileStorage: MediaFileStorage = DefaultMediaFileStorage(directoryName: "BreedGallery")
    private lazy var breedExploreGalleryMediaFileStorage: MediaFileStorage = DefaultMediaFileStorage(directoryName: "BreedExploreGallery")
    private lazy var favoritesMediaFileStorage: MediaFileStorage = DefaultMediaFileStorage(directoryName: "Favorites")
    private lazy var dogCeoRemoteDataSource = DogCeoRemoteDataSource(httpUtility: dogCeoHTTPUtility)
    private lazy var dogCeoBreedGalleryRemoteDataSource = DogCeoBreedGalleryRemoteDataSource(httpUtility: dogCeoHTTPUtility)
    private lazy var randomDogRemoteDataSource = RandomDogRemoteDataSource(
        httpUtility: randomDogHTTPUtility,
        mediaQualityEvaluator: MediaQuality.spotlight
    )
    private lazy var randomDogMiniMomentRemoteDataSource = RandomDogMiniMomentRemoteDataSource(
        httpUtility: randomDogHTTPUtility,
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

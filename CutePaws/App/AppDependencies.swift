import Foundation
import SwiftData

@MainActor
final class AppDependencies {
    let logger: AppLogger
    let httpUtility: HTTPUtility
    let discoverModelContainer: ModelContainer
    let spotlightModelContainer: ModelContainer

    init() {
        logger = AppLogger(subsystem: Bundle.main.bundleIdentifier ?? "CutePaws")
        httpUtility = HTTPUtility(timeout: 20.0)

        do {
            let applicationSupportURL = try Self.makeApplicationSupportDirectory(using: .default)
            let discoverStoreURL = applicationSupportURL.appendingPathComponent("discover.store")
            let discoverConfiguration = ModelConfiguration(url: discoverStoreURL)
            let spotlightStoreURL = applicationSupportURL.appendingPathComponent("spotlight.store")
            let spotlightConfiguration = ModelConfiguration(url: spotlightStoreURL)

            #if DEBUG
            print("SwiftData discover store path:", discoverStoreURL.path)
            print("SwiftData spotlight store path:", spotlightStoreURL.path)
            #endif

            discoverModelContainer = try ModelContainer(
                for: StoredMediaItem.self,
                configurations: discoverConfiguration
            )
            spotlightModelContainer = try ModelContainer(
                for: StoredSpotlightItem.self,
                configurations: spotlightConfiguration
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

    private lazy var imageDownloadService = ImageDownloadService(httpUtility: httpUtility)
    private lazy var imageMetadataService: ImageMetadataService = DefaultImageMetadataService()
    private lazy var mediaFileStorage: MediaFileStorage = DefaultMediaFileStorage(directoryName: "DailyPicks")
    private lazy var spotlightMediaFileStorage: MediaFileStorage = DefaultMediaFileStorage(directoryName: "SpotlightMedia")
    private lazy var dogCeoRemoteDataSource = DogCeoRemoteDataSource(httpUtility: httpUtility)
    private lazy var randomDogRemoteDataSource = RandomDogRemoteDataSource(httpUtility: httpUtility)

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
}

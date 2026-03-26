import Foundation
import SwiftData

@MainActor
final class AppDependencies {
    private let logger: AppLogger
    private let httpUtility: HTTPUtility
    private let discoverModelContainer: ModelContainer
    private let spotlightModelContainer: ModelContainer

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

    private lazy var discoverStore = SwiftDataDiscoverStore(
        container: discoverModelContainer,
        fileStorage: mediaFileStorage,
        logger: logger
    )
    private lazy var spotlightStore = SwiftDataSpotlightStore(
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

    private lazy var discoverRepository: DiscoverRepository = DiscoverRepositoryImpl(
        remoteDataSource: dogCeoRemoteDataSource,
        imageDownloadService: imageDownloadService,
        imageMetadataService: imageMetadataService,
        mediaFileStorage: mediaFileStorage,
        store: discoverStore,
        logger: logger
    )
    private lazy var spotlightRepository: SpotlightRepository = SpotlightRepositoryImpl(
        remoteDataSource: randomDogRemoteDataSource,
        imageDownloadService: imageDownloadService,
        imageMetadataService: imageMetadataService,
        mediaFileStorage: spotlightMediaFileStorage,
        store: spotlightStore,
        logger: logger
    )

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

    private static func makeApplicationSupportDirectory(using fileManager: FileManager) throws -> URL {
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

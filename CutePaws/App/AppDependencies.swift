import Foundation
import SwiftData

@MainActor
final class AppDependencies {
    private let logger: AppLogger
    private let httpUtility: HTTPUtility
    private let modelContainer: ModelContainer

    init() {
        logger = AppLogger(subsystem: Bundle.main.bundleIdentifier ?? "CutePaws")
        httpUtility = HTTPUtility(timeout: 20.0)

        do {
            let applicationSupportURL = try Self.makeApplicationSupportDirectory(using: .default)
            let storeURL = applicationSupportURL.appendingPathComponent("discover.store")
            let configuration = ModelConfiguration(url: storeURL)

            #if DEBUG
            print("SwiftData store path:", storeURL.path)
            #endif

            modelContainer = try ModelContainer(
                for: StoredMediaItem.self,
                configurations: configuration
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    private lazy var discoverStore = SwiftDataDiscoverStore(
        container: modelContainer,
        fileStorage: mediaFileStorage,
        logger: logger
    )

    private lazy var imageDownloadService = ImageDownloadService(httpUtility: httpUtility)
    private lazy var imageMetadataService: ImageMetadataService = DefaultImageMetadataService()
    private lazy var mediaFileStorage: MediaFileStorage = DefaultMediaFileStorage()
    private lazy var dogCeoRemoteDataSource = DogCeoRemoteDataSource(httpUtility: httpUtility)

    private lazy var discoverRepository: DiscoverRepository = DiscoverRepositoryImpl(
        remoteDataSource: dogCeoRemoteDataSource,
        imageDownloadService: imageDownloadService,
        imageMetadataService: imageMetadataService,
        mediaFileStorage: mediaFileStorage,
        store: discoverStore,
        logger: logger
    )

    func makeDiscoverViewModel() -> DiscoverViewModel {
        let initialItems = discoverStore.fetchItemsSnapshot(limit: 20)

        #if DEBUG
        print("AppDependencies.makeDiscoverViewModel initialItems:", initialItems.count)
        #endif

        return DiscoverViewModel(
            repository: discoverRepository,
            initialItems: initialItems,
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

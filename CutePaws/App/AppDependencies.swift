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
            modelContainer = try ModelContainer(for: StoredMediaItem.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    private lazy var discoverStore = SwiftDataDiscoverStore(
        container: modelContainer,
        logger: logger
    )

    private lazy var imageDownloadService = ImageDownloadService(httpUtility: httpUtility)
    private lazy var dogCeoRemoteDataSource = DogCeoRemoteDataSource(httpUtility: httpUtility)

    private lazy var discoverRepository: DiscoverRepository = DiscoverRepositoryImpl(
        remoteDataSource: dogCeoRemoteDataSource,
        imageDownloadService: imageDownloadService,
        store: discoverStore,
        logger: logger
    )

    func makeDiscoverViewModel() -> DiscoverViewModel {
        DiscoverViewModel(repository: discoverRepository)
    }
}

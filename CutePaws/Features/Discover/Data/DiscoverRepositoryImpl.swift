import Foundation
import ImageIO

final class DiscoverRepositoryImpl: DiscoverRepository {
    private let remoteDataSource: DogCeoRemoteDataSource
    private let imageDownloadService: ImageDownloadService
    private let store: SwiftDataDiscoverStore
    private let logger: AppLogger

    init(
        remoteDataSource: DogCeoRemoteDataSource,
        imageDownloadService: ImageDownloadService,
        store: SwiftDataDiscoverStore,
        logger: AppLogger
    ) {
        self.remoteDataSource = remoteDataSource
        self.imageDownloadService = imageDownloadService
        self.store = store
        self.logger = logger
    }

    func prepare() async {
        await store.deleteUnsupportedItems()
    }

    func loadCached(limit: Int) async -> [MediaItem] {
        await store.fetchItems(limit: limit)
    }

    func cachedCount() async -> Int {
        await store.itemCount()
    }

    func fetchAndStore(count: Int) async throws {
        guard count > 0 else { return }

        let urls = try await remoteDataSource.fetchImageURLs(count: count)
        let downloadedItems = await imageDownloadService.downloadImages(from: urls, maxConcurrent: 10)
        let items = await makeMediaItems(from: downloadedItems)

        guard !items.isEmpty else {
            logger.error("Repository refresh failed", metadata: ["count": "\(count)"])
            throw URLError(.cannotDecodeContentData)
        }

        await store.save(items)
    }

    func trimToLatest(maxCount: Int) async {
        await store.trimToLatest(maxCount: maxCount)
    }

    private static func aspectRatio(from data: Data) -> Double? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
            let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
            height > 0
        else {
            return nil
        }

        return Double(width / height)
    }

    private func makeMediaItems(from downloadedItems: [(url: URL, data: Data)]) async -> [MediaItem] {
        downloadedItems.compactMap { Self.makeMediaItem(url: $0.url, data: $0.data) }
    }

    private static func makeMediaItem(url: URL, data: Data) -> MediaItem? {
        return MediaItem(
            remoteURL: url,
            imageData: data,
            aspectRatio: aspectRatio(from: data) ?? 1.0,
            source: .dogCeo,
            createdAt: Date()
        )
    }
}

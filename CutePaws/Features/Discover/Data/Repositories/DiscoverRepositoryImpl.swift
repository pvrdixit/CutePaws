import Foundation

final class DiscoverRepositoryImpl: DiscoverRepository {
    private let remoteDataSource: DiscoverRemoteDataSource
    private let imageDownloadService: ImageDownloading
    private let imageMetadataService: ImageMetadataService
    private let dailyPicksQuality: MediaQualityEvaluator
    private let mediaFileStorage: MediaFileStorage
    private let store: DiscoverStore
    private let logger: AppLogger

    init(
        remoteDataSource: DiscoverRemoteDataSource,
        imageDownloadService: ImageDownloading,
        imageMetadataService: ImageMetadataService,
        dailyPicksQuality: MediaQualityEvaluator,
        mediaFileStorage: MediaFileStorage,
        store: DiscoverStore,
        logger: AppLogger
    ) {
        self.remoteDataSource = remoteDataSource
        self.imageDownloadService = imageDownloadService
        self.imageMetadataService = imageMetadataService
        self.dailyPicksQuality = dailyPicksQuality
        self.mediaFileStorage = mediaFileStorage
        self.store = store
        self.logger = logger
    }

    func prepare() async {
        debugLog("prepare begin")
        await store.deleteInvalidItems()
        debugLog("prepare end")
    }

    func loadCached(limit: Int) async -> [MediaItem] {
        await store.fetchItems(limit: limit)
    }

    func cachedCount() async -> Int {
        await store.itemCount()
    }

    func fetchAndStore(count: Int) async throws {
        guard count > 0 else { return }

        debugLog("fetchAndStore begin requestedCount=\(count)")

        var collectedItems: [MediaItem] = []
        let existingItems = await store.fetchItems(limit: .max)
        var seenRemoteURLs = Set(existingItems.map { $0.remoteURL.absoluteString })
        var attempts = 0
        var downloadedCount = 0

        while collectedItems.count < count, attempts < 4 {
            let remainingCount = count - collectedItems.count
            let requestCount = min(50, max(remainingCount * 3, 10))
            let urls = try await remoteDataSource.fetchImageURLs(count: requestCount)

            // Skip URLs already present in the store to avoid redundant downloads.
            // Also de-dupe within this batch, just in case the provider repeats URLs.
            var seenBatch = Set<String>()
            let urlsToDownload = urls.filter { url in
                let key = url.absoluteString
                return !seenRemoteURLs.contains(key) && seenBatch.insert(key).inserted
            }

            guard !urlsToDownload.isEmpty else {
                attempts += 1
                continue
            }

            let downloadedItems = await imageDownloadService.downloadImages(from: urlsToDownload, maxConcurrent: 10)
            downloadedCount += downloadedItems.count
            let newItems = makeMediaItems(from: downloadedItems)
            let acceptedCount = newItems.count
            var duplicateDropCount = 0

            for preparedItem in newItems {
                let item = preparedItem.item
                let remoteURLString = item.remoteURL.absoluteString

                if seenRemoteURLs.insert(remoteURLString).inserted {
                    collectedItems.append(item)
                } else if let localFilePath = item.localFilePath {
                    // URL already exists in the store; discard downloaded file for cleanliness.
                    mediaFileStorage.removeFile(at: localFilePath)
                    duplicateDropCount += 1
                }
            }

            debugLog(
                "fetchAndStore attempt=\(attempts + 1) requestCount=\(requestCount) urls=\(urls.count) downloaded=\(downloadedItems.count) accepted=\(acceptedCount) duplicateDrops=\(duplicateDropCount) collected=\(collectedItems.count)"
            )

            attempts += 1
        }

        guard !collectedItems.isEmpty else {
            logger.error(
                "Repository refresh failed",
                metadata: [
                    "count": "\(count)",
                    "attempts": "\(attempts)",
                    "downloaded": "\(downloadedCount)"
                ]
            )
            throw URLError(.cannotDecodeContentData)
        }

        let itemsToSave = Array(collectedItems.prefix(count))
        cleanupUnusedFiles(for: collectedItems.dropFirst(count))
        debugLog("fetchAndStore saving items=\(itemsToSave.count) extraFilesCleaned=\(max(0, collectedItems.count - itemsToSave.count))")
        await store.save(itemsToSave)
        let finalCount = await store.itemCount()
        debugLog("fetchAndStore end storeCount=\(finalCount)")
    }

    func trimToLatest(maxCount: Int) async {
        debugLog("trimToLatest requested maxCount=\(maxCount)")
        await store.trimToLatest(maxCount: maxCount)
        let finalCount = await store.itemCount()
        debugLog("trimToLatest end storeCount=\(finalCount)")
    }

    private func makeMediaItems(from downloadedItems: [(url: URL, data: Data)]) -> [PreparedMediaItem] {
        downloadedItems.compactMap { makeMediaItem(url: $0.url, data: $0.data) }
    }

    private func makeMediaItem(url: URL, data: Data) -> PreparedMediaItem? {
        guard dailyPicksQuality.passesDownloadedPayload(data) else {
            return nil
        }

        let localFilePath: String

        do {
            localFilePath = try mediaFileStorage.saveImageData(data, suggestedPathExtension: url.pathExtension)
        } catch {
            logger.error("Image file save failed", metadata: ["url": url.absoluteString])
            return nil
        }

        return PreparedMediaItem(
            item: MediaItem(
                remoteURL: url,
                localFilePath: localFilePath,
                aspectRatio: imageMetadataService.aspectRatio(from: data) ?? 1.0,
                createdAt: Date()
            )
        )
    }

    private func cleanupUnusedFiles<S: Sequence>(for items: S) where S.Element == MediaItem {
        for item in items {
            if let localFilePath = item.localFilePath {
                mediaFileStorage.removeFile(at: localFilePath)
            }
        }
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("DiscoverRepositoryImpl:", message)
        #endif
    }
}

private struct PreparedMediaItem {
    let item: MediaItem
}

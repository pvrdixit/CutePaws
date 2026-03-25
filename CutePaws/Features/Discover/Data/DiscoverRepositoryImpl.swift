import CryptoKit
import Foundation

final class DiscoverRepositoryImpl: DiscoverRepository {
    private let remoteDataSource: DiscoverRemoteDataSource
    private let imageDownloadService: ImageDownloading
    private let imageMetadataService: ImageMetadataService
    private let mediaFileStorage: MediaFileStorage
    private let store: DiscoverStore
    private let logger: AppLogger

    init(
        remoteDataSource: DiscoverRemoteDataSource,
        imageDownloadService: ImageDownloading,
        imageMetadataService: ImageMetadataService,
        mediaFileStorage: MediaFileStorage,
        store: DiscoverStore,
        logger: AppLogger
    ) {
        self.remoteDataSource = remoteDataSource
        self.imageDownloadService = imageDownloadService
        self.imageMetadataService = imageMetadataService
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
        var seenRemoteURLs = Set<String>()
        var seenContentFingerprints = Set(
            await store.fetchItems(limit: .max).compactMap { contentFingerprint(at: $0.localFilePath) }
        )
        var attempts = 0
        var downloadedCount = 0

        while collectedItems.count < count, attempts < 4 {
            let remainingCount = count - collectedItems.count
            let requestCount = min(50, max(remainingCount * 3, 10))
            let urls = try await remoteDataSource.fetchImageURLs(count: requestCount)
            let downloadedItems = await imageDownloadService.downloadImages(from: urls, maxConcurrent: 10)
            downloadedCount += downloadedItems.count
            let newItems = makeMediaItems(from: downloadedItems)
            let acceptedCount = newItems.count
            var duplicateDropCount = 0

            for preparedItem in newItems {
                let item = preparedItem.item
                let remoteURLString = item.remoteURL.absoluteString

                if seenRemoteURLs.insert(remoteURLString).inserted,
                   seenContentFingerprints.insert(preparedItem.contentFingerprint).inserted {
                    collectedItems.append(item)
                } else if let localFilePath = item.localFilePath {
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
        guard MediaQualityEvaluator.isAcceptableImage(data: data) else {
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
                source: .dogCeo,
                createdAt: Date()
            ),
            contentFingerprint: contentFingerprint(for: data)
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

    private func contentFingerprint(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func contentFingerprint(at path: String?) -> String? {
        guard
            let path,
            let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedIfSafe])
        else {
            return nil
        }

        return contentFingerprint(for: data)
    }
}

private struct PreparedMediaItem {
    let item: MediaItem
    let contentFingerprint: String
}

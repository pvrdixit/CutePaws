import Foundation

final class SpotlightRepositoryImpl: SpotlightRepository {
    private let remoteDataSource: SpotlightRemoteDataSource
    private let imageDownloadService: ImageDownloading
    private let imageMetadataService: ImageMetadataService
    private let mediaQualityEvaluator: MediaQualityEvaluator
    private let mediaFileStorage: MediaFileStorage
    private let store: SpotlightStore
    private let logger: AppLogger

    init(
        remoteDataSource: SpotlightRemoteDataSource,
        imageDownloadService: ImageDownloading,
        imageMetadataService: ImageMetadataService,
        mediaQualityEvaluator: MediaQualityEvaluator,
        mediaFileStorage: MediaFileStorage,
        store: SpotlightStore,
        logger: AppLogger
    ) {
        self.remoteDataSource = remoteDataSource
        self.imageDownloadService = imageDownloadService
        self.imageMetadataService = imageMetadataService
        self.mediaQualityEvaluator = mediaQualityEvaluator
        self.mediaFileStorage = mediaFileStorage
        self.store = store
        self.logger = logger
    }

    func prepare() async {
        await store.deleteInvalidItems()
    }

    func loadCached(limit: Int) async -> [SpotlightItem] {
        await store.fetchItems(limit: limit)
    }

    func cachedCount() async -> Int {
        await store.itemCount()
    }

    func fetchAndStore(count: Int) async throws {
        guard count > 0 else { return }

        let existingItems = await store.fetchItems(limit: .max)
        var seenRemoteURLs = Set(existingItems.map { $0.remoteURL.absoluteString })
        var collectedItems: [SpotlightItem] = []
        var attempts = 0

        while collectedItems.count < count, attempts < 6 {
            let remaining = count - collectedItems.count
            let candidates = try await remoteDataSource.fetchImageCandidates(count: remaining)
            let urls = candidates.map(\.url)
            let fileSizesByURL = Dictionary(
                uniqueKeysWithValues: candidates.map { ($0.url.absoluteString, $0.fileSizeBytes) }
            )

            let downloaded = await imageDownloadService.downloadImages(from: urls, maxConcurrent: 4)

            for (url, data) in downloaded {
                let key = url.absoluteString
                guard seenRemoteURLs.insert(key).inserted else { continue }
                guard mediaQualityEvaluator.passesDownloadedPayload(data) else { continue }

                do {
                    let localPath = try mediaFileStorage.saveImageData(data, suggestedPathExtension: url.pathExtension)
                    let fileSize = fileSizesByURL[key] ?? data.count
                    let aspectRatio = imageMetadataService.aspectRatio(from: data) ?? 1.5
                    collectedItems.append(
                        SpotlightItem(
                            remoteURL: url,
                            localFilePath: localPath,
                            fileSizeBytes: fileSize,
                            createdAt: Date(),
                            aspectRatio: aspectRatio
                        )
                    )
                } catch {
                    logger.error("Spotlight image file save failed", metadata: ["url": key])
                }
            }

            attempts += 1
        }

        guard !collectedItems.isEmpty else {
            logger.error("Spotlight refresh failed", metadata: ["count": "\(count)"])
            throw URLError(.cannotDecodeContentData)
        }

        let itemsToSave = Array(collectedItems.prefix(count))
        cleanupUnusedFiles(for: collectedItems.dropFirst(count))
        await store.save(itemsToSave)
    }

    func trimToLatest(maxCount: Int) async {
        await store.trimToLatest(maxCount: maxCount)
    }

    private func cleanupUnusedFiles<S: Sequence>(for items: S) where S.Element == SpotlightItem {
        for item in items {
            if let localFilePath = item.localFilePath {
                mediaFileStorage.removeFile(at: localFilePath)
            }
        }
    }
}


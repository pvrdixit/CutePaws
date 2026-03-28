import Foundation

final class AnimatedGifRepositoryImpl: AnimatedGifRepository {
    private let remoteDataSource: AnimatedGifRemoteDataSource
    private let imageDownloadService: ImageDownloading
    private let mediaFileStorage: MediaFileStorage
    private let store: AnimatedGifStore
    private let logger: AppLogger

    init(
        remoteDataSource: AnimatedGifRemoteDataSource,
        imageDownloadService: ImageDownloading,
        mediaFileStorage: MediaFileStorage,
        store: AnimatedGifStore,
        logger: AppLogger
    ) {
        self.remoteDataSource = remoteDataSource
        self.imageDownloadService = imageDownloadService
        self.mediaFileStorage = mediaFileStorage
        self.store = store
        self.logger = logger
    }

    func prepare() async {
        await store.deleteInvalidItems()
    }

    func loadCached(limit: Int) async -> [AnimatedGifItem] {
        await store.fetchItems(limit: limit)
    }

    func cachedCount() async -> Int {
        await store.itemCount()
    }

    func fetchAndStore(count: Int) async throws {
        guard count > 0 else { return }

        let existingItems = await store.fetchItems(limit: .max)
        var seenRemoteURLs = Set(existingItems.map { $0.remoteURL.absoluteString })
        var failedRemoteURLs = Set<String>()
        var collectedItems: [AnimatedGifItem] = []
        var attempts = 0

        while collectedItems.count < count, attempts < 6 {
            let remaining = count - collectedItems.count
            let candidateTarget = max(remaining * 4, 4)
            let candidates = try await remoteDataSource.fetchGifCandidates(count: candidateTarget)
            let filteredCandidates = candidates.filter { !failedRemoteURLs.contains($0.url.absoluteString) }
            let urls = filteredCandidates.map(\.url)
            let fileSizesByURL = Dictionary(uniqueKeysWithValues: candidates.map { ($0.url.absoluteString, $0.fileSizeBytes) })

            let downloaded = await imageDownloadService.downloadImages(from: urls, maxConcurrent: 2)
            for (url, data) in downloaded {
                let key = url.absoluteString
                guard seenRemoteURLs.insert(key).inserted else { continue }

                do {
                    let localPath = try mediaFileStorage.saveImageData(data, suggestedPathExtension: "gif")
                    let fileURL = URL(fileURLWithPath: localPath)
                    guard
                        let ratio = MediaAspectRatioReader.gifAspectRatio(fileURL: fileURL),
                        MediaAspectRatioReader.isAcceptableMediaRailAspectRatio(ratio)
                    else {
                        mediaFileStorage.removeFile(at: localPath)
                        continue
                    }
                    let fileSize = fileSizesByURL[key] ?? data.count
                    collectedItems.append(
                        AnimatedGifItem(
                            remoteURL: url,
                            localFilePath: localPath,
                            fileSizeBytes: fileSize,
                            createdAt: Date()
                        )
                    )
                } catch {
                    logger.error("AnimatedGif file save failed", metadata: ["url": key])
                }
            }
            if downloaded.isEmpty {
                failedRemoteURLs.formUnion(urls.map(\.absoluteString))
            }

            attempts += 1
        }

        guard !collectedItems.isEmpty else {
            logger.error("AnimatedGif refresh failed", metadata: ["count": "\(count)"])
            throw URLError(.cannotDecodeContentData)
        }

        let itemsToSave = Array(collectedItems.prefix(count))
        cleanupUnusedFiles(for: collectedItems.dropFirst(count))
        await store.save(itemsToSave)
    }

    func trimToLatest(maxCount: Int) async {
        await store.trimToLatest(maxCount: maxCount)
    }

    private func cleanupUnusedFiles<S: Sequence>(for items: S) where S.Element == AnimatedGifItem {
        for item in items {
            if let localFilePath = item.localFilePath {
                mediaFileStorage.removeFile(at: localFilePath)
            }
        }
    }
}


import Foundation

final class MiniMomentRepositoryImpl: MiniMomentRepository {
    private let remoteDataSource: MiniMomentRemoteDataSource
    private let imageDownloadService: ImageDownloading
    private let mediaFileStorage: MediaFileStorage
    private let store: MiniMomentStore
    private let logger: AppLogger

    init(
        remoteDataSource: MiniMomentRemoteDataSource,
        imageDownloadService: ImageDownloading,
        mediaFileStorage: MediaFileStorage,
        store: MiniMomentStore,
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

    func loadCached(limit: Int) async -> [MiniMomentItem] {
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
        var collectedItems: [MiniMomentItem] = []
        var attempts = 0

        while collectedItems.count < count, attempts < 6 {
            let remaining = count - collectedItems.count
            let candidateTarget = max(remaining * 4, 4)
            let candidates = try await remoteDataSource.fetchClipCandidates(count: candidateTarget)
            let filteredCandidates = candidates.filter { !failedRemoteURLs.contains($0.url.absoluteString) }
            let urls = filteredCandidates.map(\.url)
            let fileSizesByURL = Dictionary(uniqueKeysWithValues: candidates.map { ($0.url.absoluteString, $0.fileSizeBytes) })

            let downloaded = await imageDownloadService.downloadImages(from: urls, maxConcurrent: 2)
            for (url, data) in downloaded {
                let key = url.absoluteString
                guard seenRemoteURLs.insert(key).inserted else { continue }

                do {
                    let localPath = try mediaFileStorage.saveImageData(data, suggestedPathExtension: "mp4")
                    let fileURL = URL(fileURLWithPath: localPath)
                    guard
                        let ratio = await MediaAspectRatioReader.videoAspectRatio(fileURL: fileURL),
                        MediaAspectRatioReader.isAcceptableMediaRailAspectRatio(ratio)
                    else {
                        mediaFileStorage.removeFile(at: localPath)
                        continue
                    }
                    let fileSize = fileSizesByURL[key] ?? data.count
                    collectedItems.append(
                        MiniMomentItem(
                            remoteURL: url,
                            localFilePath: localPath,
                            fileSizeBytes: fileSize,
                            createdAt: Date()
                        )
                    )
                } catch {
                    logger.error("MiniMoment file save failed", metadata: ["url": key])
                }
            }
            if downloaded.isEmpty {
                failedRemoteURLs.formUnion(urls.map(\.absoluteString))
            }

            attempts += 1
        }

        guard !collectedItems.isEmpty else {
            logger.error("MiniMoment refresh failed", metadata: ["count": "\(count)"])
            throw URLError(.cannotDecodeContentData)
        }

        let itemsToSave = Array(collectedItems.prefix(count))
        cleanupUnusedFiles(for: collectedItems.dropFirst(count))
        await store.save(itemsToSave)
    }

    func trimToLatest(maxCount: Int) async {
        await store.trimToLatest(maxCount: maxCount)
    }

    private func cleanupUnusedFiles<S: Sequence>(for items: S) where S.Element == MiniMomentItem {
        for item in items {
            if let localFilePath = item.localFilePath {
                mediaFileStorage.removeFile(at: localFilePath)
            }
        }
    }
}


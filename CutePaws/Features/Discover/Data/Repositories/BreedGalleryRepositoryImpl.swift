import Foundation

final class BreedGalleryRepositoryImpl: BreedGalleryRepository, @unchecked Sendable {
    private let remoteDataSource: BreedGalleryRemoteDataSource
    private let imageDownloadService: ImageDownloading
    private let imageMetadataService: ImageMetadataService
    private let breedImagesQuality: MediaQualityEvaluator
    private let breedThumbnailQuality: MediaQualityEvaluator
    private let thumbnailCompressor: ImageCompressor
    private let exploreGalleryFileStorage: MediaFileStorage
    private let galleryStore: BreedGalleryStore
    private let exploreGalleryStore: BreedExploreGalleryStore
    private let thumbnailStore: BreedThumbnailStore
    private let catalogStore: BreedCatalogStore
    private let logger: AppLogger

    private let thumbnailRandomAttempts = 3
    private let thumbnailConcurrentJobs = 4
    private let exploreGalleryDownloadConcurrency = 4
    private let exploreGalleryFetchBudgetSeconds: TimeInterval = 12
    private let exploreSingleImageTimeoutSeconds: TimeInterval = 40

    init(
        remoteDataSource: BreedGalleryRemoteDataSource,
        imageDownloadService: ImageDownloading,
        imageMetadataService: ImageMetadataService,
        breedImagesQuality: MediaQualityEvaluator,
        breedThumbnailQuality: MediaQualityEvaluator,
        thumbnailCompressor: ImageCompressor,
        exploreGalleryFileStorage: MediaFileStorage,
        galleryStore: BreedGalleryStore,
        exploreGalleryStore: BreedExploreGalleryStore,
        thumbnailStore: BreedThumbnailStore,
        catalogStore: BreedCatalogStore,
        logger: AppLogger
    ) {
        self.remoteDataSource = remoteDataSource
        self.imageDownloadService = imageDownloadService
        self.imageMetadataService = imageMetadataService
        self.breedImagesQuality = breedImagesQuality
        self.breedThumbnailQuality = breedThumbnailQuality
        self.thumbnailCompressor = thumbnailCompressor
        self.exploreGalleryFileStorage = exploreGalleryFileStorage
        self.galleryStore = galleryStore
        self.exploreGalleryStore = exploreGalleryStore
        self.thumbnailStore = thumbnailStore
        self.catalogStore = catalogStore
        self.logger = logger
    }

    func prepare() async {
        await galleryStore.deleteInvalidItems()
        await exploreGalleryStore.deleteInvalidItems()
        await thumbnailStore.deleteInvalidItems()
    }

    func loadExploreBreedListSnapshot() async -> ExploreBreedListSnapshot? {
        guard await catalogStore.isThumbnailBootstrapCompleted(),
              let breedNames = await catalogStore.loadPersistedBreedNames()
        else {
            return nil
        }
        let thumbnails = await thumbnailStore.fetchAllSnapshot()
        return ExploreBreedListSnapshot.build(breedNames: breedNames, thumbnails: thumbnails)
    }

    func loadCachedThumbnails() async -> [BreedThumbnailItem] {
        await thumbnailStore.fetchAllSnapshot()
    }

    func syncAllThumbnails() async throws {
        if await catalogStore.isThumbnailBootstrapCompleted() {
            return
        }

        await prepare()

        var breedNames = await catalogStore.loadPersistedBreedNames()
        if breedNames == nil {
            breedNames = try await remoteDataSource.fetchFlatBreedsList()
            await catalogStore.saveBreedNames(breedNames!)
        }

        guard let names = breedNames else { return }

        let existingKeys = await thumbnailStore.existingCatalogKeys()
        var workBreeds: [String] = []
        workBreeds.reserveCapacity(names.count)

        for breedName in names {
            try Task.checkCancellation()
            let key = BreedThumbnailItem.catalogKey(breedName: breedName, subBreedName: "")
            if !existingKeys.contains(key) {
                workBreeds.append(breedName)
            }
        }

        let semaphore = AsyncSemaphore(value: thumbnailConcurrentJobs)
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for breedName in workBreeds {
                    group.addTask { [self] in
                        try Task.checkCancellation()
                        await semaphore.acquire()
                        do {
                            try Task.checkCancellation()
                            try await self.runThumbnailJob(breedName: breedName)
                        } catch {
                            await semaphore.release()
                            throw error
                        }
                        await semaphore.release()
                    }
                }
                try await group.waitForAll()
            }
            await catalogStore.markThumbnailBootstrapCompleted()
        } catch is CancellationError {
            throw CancellationError()
        }
    }

    func loadBreedExploreGalleryMediaItems(breedName: String) async throws -> [MediaItem] {
        try Task.checkCancellation()
        let galleryKey = BreedThumbnailItem.catalogKey(breedName: breedName, subBreedName: "")
        let apiURLs = try await remoteDataSource.fetchAllImageURLs(breedName: breedName)

        var rowByPath = Self.rowMap(from: await exploreGalleryStore.loadRows(galleryKey: galleryKey))
        let deadline = Date().addingTimeInterval(exploreGalleryFetchBudgetSeconds)

        var workItems: [(url: URL, relativePath: String)] = []
        workItems.reserveCapacity(apiURLs.count)
        for url in apiURLs {
            guard let rel = APIConstants.DogCeo.breedImageRelativePath(from: url) else { continue }
            if rowByPath[rel]?.qualityRejected == true { continue }
            if Self.hasUsableLocalFile(row: rowByPath[rel], fileStorage: exploreGalleryFileStorage) { continue }
            workItems.append((url, rel))
        }

        let workQueue = ExploreGalleryWorkQueueActor(items: workItems, deadline: deadline)
        let quality = breedImagesQuality
        let downloadService = imageDownloadService
        let metadata = imageMetadataService
        let fileStorage = exploreGalleryFileStorage
        let store = exploreGalleryStore
        let perImageTimeout = exploreSingleImageTimeoutSeconds
        let concurrency = exploreGalleryDownloadConcurrency

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<concurrency {
                group.addTask {
                    while let (url, relPath) = await workQueue.dequeue() {
                        if Task.isCancelled { return }
                        guard let data = await downloadService.downloadImage(from: url, timeoutInterval: perImageTimeout) else {
                            continue
                        }
                        let passesQuality = await MainActor.run {
                            quality.passesDownloadedPayload(data)
                        }
                        if !passesQuality {
                            await store.markQualityRejected(galleryKey: galleryKey, relativeImagePath: relPath)
                            continue
                        }
                        let saved = await MainActor.run { () -> (path: String, aspect: Double)? in
                            do {
                                let localPath = try fileStorage.saveImageData(data, suggestedPathExtension: url.pathExtension)
                                let aspect = metadata.aspectRatio(from: data) ?? 1.0
                                return (localPath, aspect)
                            } catch {
                                return nil
                            }
                        }
                        guard let saved else { continue }
                        await store.saveAccepted(
                            galleryKey: galleryKey,
                            relativeImagePath: relPath,
                            localFilePath: saved.path,
                            aspectRatio: saved.aspect
                        )
                    }
                }
            }
        }

        let finalRows = await exploreGalleryStore.loadRows(galleryKey: galleryKey)
        rowByPath = Self.rowMap(from: finalRows)

        var result: [MediaItem] = []
        result.reserveCapacity(apiURLs.count)
        for url in apiURLs {
            guard let rel = APIConstants.DogCeo.breedImageRelativePath(from: url) else { continue }
            guard let row = rowByPath[rel], !row.qualityRejected else { continue }
            guard let ref = row.localFilePath,
                  let diskPath = exploreGalleryFileStorage.filePath(for: ref),
                  exploreGalleryFileStorage.fileExists(at: diskPath)
            else { continue }
            guard let remote = APIConstants.DogCeo.breedImageCDNURL(relativePath: rel) else { continue }
            result.append(
                MediaItem(
                    remoteURL: remote,
                    localFilePath: diskPath,
                    aspectRatio: row.aspectRatio,
                    createdAt: row.createdAt
                )
            )
        }
        return result
    }

    private static func rowMap(from rows: [BreedExploreGalleryPersistedRow]) -> [String: BreedExploreGalleryPersistedRow] {
        Dictionary(uniqueKeysWithValues: rows.map { ($0.relativeImagePath, $0) })
    }

    private static func hasUsableLocalFile(
        row: BreedExploreGalleryPersistedRow?,
        fileStorage: MediaFileStorage
    ) -> Bool {
        guard let row, !row.qualityRejected, let ref = row.localFilePath else { return false }
        guard let path = fileStorage.filePath(for: ref) else { return false }
        return fileStorage.fileExists(at: path)
    }

    private func runThumbnailJob(breedName: String) async throws {
        for _ in 0..<thumbnailRandomAttempts {
            try Task.checkCancellation()

            let urls: [URL]
            do {
                urls = try await remoteDataSource.fetchRandomImageURLs(breedName: breedName, count: 1)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                logger.error(
                    "Breed thumbnail fetch URLs failed",
                    metadata: [
                        "breedName": breedName,
                        "error": String(describing: error)
                    ]
                )
                continue
            }

            guard let url = urls.first else { continue }

            let downloaded = await imageDownloadService.downloadImages(from: [url], maxConcurrent: 1)
            guard let data = downloaded.first?.data else { continue }

            guard breedThumbnailQuality.passesDownloadedPayload(data) else { continue }

            let compressor = thumbnailCompressor
            let compressed = await Task.detached(priority: .userInitiated) {
                compressor.compressedJPEGData(from: data)
            }.value

            guard let compressed else { continue }

            let aspectRatio =
                imageMetadataService.aspectRatio(from: compressed)
                ?? imageMetadataService.aspectRatio(from: data)
                ?? 1.0

            let item = BreedThumbnailItem(
                breedName: breedName,
                subBreedName: "",
                thumbnailImageData: compressed,
                aspectRatio: aspectRatio,
                remoteSourceURL: url,
                updatedAt: Date()
            )

            await thumbnailStore.save([item])
            return
        }

        logger.error(
            "Breed thumbnail: no acceptable image after retries",
            metadata: ["breedName": breedName]
        )
    }
}

private actor ExploreGalleryWorkQueueActor {
    private var pending: [(url: URL, relativePath: String)]
    private let deadline: Date

    init(items: [(url: URL, relativePath: String)], deadline: Date) {
        pending = items
        self.deadline = deadline
    }

    func dequeue() -> (url: URL, relativePath: String)? {
        guard Date() < deadline, !pending.isEmpty else { return nil }
        return pending.removeFirst()
    }
}

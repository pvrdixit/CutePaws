import Foundation

final class BreedGalleryRepositoryImpl: BreedGalleryRepository, @unchecked Sendable {
    let remoteDataSource: BreedGalleryRemoteDataSource
    let imageDownloadService: ImageDownloading
    let imageMetadataService: ImageMetadataService
    let breedImagesQuality: MediaQualityEvaluator
    let breedThumbnailQuality: MediaQualityEvaluator
    let thumbnailCompressor: ImageCompressor
    let exploreGalleryFileStorage: MediaFileStorage
    let galleryStore: BreedGalleryStore
    let exploreGalleryStore: BreedExploreGalleryStore
    let thumbnailStore: BreedThumbnailStore
    let catalogStore: BreedCatalogStore
    let logger: AppLogger

    let thumbnailRandomAttempts = 3
    let thumbnailConcurrentJobs = 4
    let exploreGalleryDownloadConcurrency = 4
    let exploreGalleryFetchBudgetSeconds: TimeInterval = 12
    let exploreSingleImageTimeoutSeconds: TimeInterval = 40

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

}


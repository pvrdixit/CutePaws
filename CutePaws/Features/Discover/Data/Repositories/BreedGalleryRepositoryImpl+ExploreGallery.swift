import Foundation

extension BreedGalleryRepositoryImpl {
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

    fileprivate static func rowMap(from rows: [BreedExploreGalleryPersistedRow]) -> [String: BreedExploreGalleryPersistedRow] {
        Dictionary(uniqueKeysWithValues: rows.map { ($0.relativeImagePath, $0) })
    }

    fileprivate static func hasUsableLocalFile(
        row: BreedExploreGalleryPersistedRow?,
        fileStorage: MediaFileStorage
    ) -> Bool {
        guard let row, !row.qualityRejected, let ref = row.localFilePath else { return false }
        guard let path = fileStorage.filePath(for: ref) else { return false }
        return fileStorage.fileExists(at: path)
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

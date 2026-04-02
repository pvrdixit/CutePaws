import Foundation

extension BreedGalleryRepositoryImpl {
    func runThumbnailJob(breedName: String) async throws {
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

import Foundation

protocol BreedGalleryRepository {
    func prepare() async
    /// After the one-time bootstrap, returns flat breeds (from `/api/breeds/list`) that have thumbnails only. `nil` until bootstrap has finished.
    func loadExploreBreedListSnapshot() async -> ExploreBreedListSnapshot?

    /// One pass: persist breed list once, fetch thumbnails with limited concurrency, then never re-hit the list or repeat thumbnail work.
    func syncAllThumbnails() async throws
    func loadCachedThumbnails() async -> [BreedThumbnailItem]

    /// Explore breed gallery: refetches URL list, reuses files by relative path (`breeds/...` suffix), skips quality-rejected paths, downloads with limited concurrency and a short wall-clock budget.
    func loadBreedExploreGalleryMediaItems(breedName: String) async throws -> [MediaItem]
}

import Foundation

protocol DiscoverRepository {
    func prepare() async
    func loadCached(limit: Int) async -> [MediaItem]
    func cachedCount() async -> Int
    func fetchAndStore(count: Int) async throws
    func trimToLatest(maxCount: Int) async
}

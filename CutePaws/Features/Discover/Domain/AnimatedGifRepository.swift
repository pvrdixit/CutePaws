import Foundation

protocol AnimatedGifRepository {
    func prepare() async
    func loadCached(limit: Int) async -> [AnimatedGifItem]
    func cachedCount() async -> Int
    func fetchAndStore(count: Int) async throws
    func trimToLatest(maxCount: Int) async
}


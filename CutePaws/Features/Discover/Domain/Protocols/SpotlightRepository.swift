import Foundation

protocol SpotlightRepository {
    func prepare() async
    func loadCached(limit: Int) async -> [SpotlightItem]
    func cachedCount() async -> Int
    func fetchAndStore(count: Int) async throws
    func trimToLatest(maxCount: Int) async
}

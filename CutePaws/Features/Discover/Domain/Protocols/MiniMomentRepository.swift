import Foundation

protocol MiniMomentRepository {
    func prepare() async
    func loadCached(limit: Int) async -> [MiniMomentItem]
    func cachedCount() async -> Int
    func fetchAndStore(count: Int) async throws
    func trimToLatest(maxCount: Int) async
}

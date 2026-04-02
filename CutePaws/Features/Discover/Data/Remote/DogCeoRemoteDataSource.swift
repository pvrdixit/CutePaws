import Foundation

protocol DiscoverRemoteDataSource {
    func fetchImageURLs(count: Int) async throws -> [URL]
}

final class DogCeoRemoteDataSource: DiscoverRemoteDataSource {
    private let httpUtility: HTTPUtility

    init(httpUtility: HTTPUtility) {
        self.httpUtility = httpUtility
    }

    func fetchImageURLs(count: Int) async throws -> [URL] {
        guard count > 0 else { return [] }

        var urls: [URL] = []
        var remainingCount = count

        while remainingCount > 0 {
            let batchCount = min(50, remainingCount)

            guard let url = APIConstants.DogCeo.randomImagesURL(count: batchCount) else {
                throw URLError(.badURL)
            }

            let request = URLRequest(url: url)
            let response = try await httpUtility.request(DogCeoListResponse.self, with: request)
            urls.append(contentsOf: response.message.compactMap(URL.init(string:)))
            remainingCount -= batchCount
        }

        return deduplicate(urls)
    }

    private func deduplicate(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { seen.insert($0.absoluteString).inserted }
    }
}

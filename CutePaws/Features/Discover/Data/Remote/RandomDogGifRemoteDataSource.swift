import Foundation

protocol AnimatedGifRemoteDataSource {
    func fetchGifCandidates(count: Int) async throws -> [RandomDogImageCandidate]
}

final class RandomDogGifRemoteDataSource: AnimatedGifRemoteDataSource {
    private let httpUtility: HTTPUtility

    init(httpUtility: HTTPUtility) {
        self.httpUtility = httpUtility
    }

    func fetchGifCandidates(count: Int) async throws -> [RandomDogImageCandidate] {
        guard count > 0 else { return [] }

        var results: [RandomDogImageCandidate] = []
        var seen = Set<String>()
        var attempts = 0
        let maxAttempts = max(20, count * 30)

        while results.count < count, attempts < maxAttempts {
            attempts += 1

            guard let url = APIConstants.RandomDog.randomGifURL() else {
                throw URLError(.badURL)
            }

            let response = try await httpUtility.request(
                RandomDogImageResponse.self,
                with: URLRequest(url: url)
            )

            guard MediaQualityEvaluator.isAcceptableGifFileSize(response.fileSizeBytes) else { continue }

            guard let mediaURL = URL(string: response.url) else {
                continue
            }

            let key = mediaURL.absoluteString
            guard seen.insert(key).inserted else {
                continue
            }

            results.append(RandomDogImageCandidate(url: mediaURL, fileSizeBytes: response.fileSizeBytes))
        }

        return results
    }
}


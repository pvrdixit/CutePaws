import Foundation

protocol MiniMomentRemoteDataSource {
    func fetchClipCandidates(count: Int) async throws -> [RandomDogImageCandidate]
}

final class RandomDogMiniMomentRemoteDataSource: MiniMomentRemoteDataSource {
    private let httpUtility: HTTPUtility
    private let mediaQualityEvaluator: MediaQualityEvaluator

    init(httpUtility: HTTPUtility, mediaQualityEvaluator: MediaQualityEvaluator) {
        self.httpUtility = httpUtility
        self.mediaQualityEvaluator = mediaQualityEvaluator
    }

    func fetchClipCandidates(count: Int) async throws -> [RandomDogImageCandidate] {
        guard count > 0 else { return [] }

        var results: [RandomDogImageCandidate] = []
        var seen = Set<String>()
        var attempts = 0
        let maxAttempts = max(20, count * 30)

        while results.count < count, attempts < maxAttempts {
            attempts += 1

            guard let url = APIConstants.RandomDog.randomVideoURL() else {
                throw URLError(.badURL)
            }

            let response = try await httpUtility.request(
                RandomDogImageResponse.self,
                with: URLRequest(url: url)
            )

            guard mediaQualityEvaluator.passesRemoteReportedFileSize(response.fileSizeBytes) else { continue }

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


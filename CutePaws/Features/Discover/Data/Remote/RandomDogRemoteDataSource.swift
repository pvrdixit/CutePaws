import Foundation

struct RandomDogImageCandidate: Sendable {
    let url: URL
    let fileSizeBytes: Int
}

protocol SpotlightRemoteDataSource {
    func fetchImageCandidates(count: Int) async throws -> [RandomDogImageCandidate]
}

final class RandomDogRemoteDataSource: SpotlightRemoteDataSource {
    private let httpUtility: HTTPUtility
    private let mediaQualityEvaluator: MediaQualityEvaluator

    init(httpUtility: HTTPUtility, mediaQualityEvaluator: MediaQualityEvaluator) {
        self.httpUtility = httpUtility
        self.mediaQualityEvaluator = mediaQualityEvaluator
    }

    func fetchImageCandidates(count: Int) async throws -> [RandomDogImageCandidate] {
        guard count > 0 else { return [] }

        var results: [RandomDogImageCandidate] = []
        var seen = Set<String>()
        var attempts = 0
        let maxAttempts = max(20, count * 30)

        while results.count < count, attempts < maxAttempts {
            attempts += 1

            guard let url = APIConstants.RandomDog.randomImageURL() else {
                throw URLError(.badURL)
            }

            let response = try await httpUtility.request(
                RandomDogImageResponse.self,
                with: URLRequest(url: url)
            )

            guard mediaQualityEvaluator.passesRemoteReportedFileSize(response.fileSizeBytes) else {
                continue
            }

            guard let imageURL = URL(string: response.url) else {
                continue
            }

            let key = imageURL.absoluteString
            guard seen.insert(key).inserted else {
                continue
            }

            results.append(RandomDogImageCandidate(url: imageURL, fileSizeBytes: response.fileSizeBytes))
        }

        return results
    }
}


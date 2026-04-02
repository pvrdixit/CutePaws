import Foundation

protocol BreedGalleryRemoteDataSource {
    func fetchFlatBreedsList() async throws -> [String]
    func fetchRandomImageURLs(breedName: String, count: Int) async throws -> [URL]
    /// Full list of image URLs for explore gallery (parent breed includes all variety images on dog.ceo).
    func fetchAllImageURLs(breedName: String) async throws -> [URL]
}

final class DogCeoBreedGalleryRemoteDataSource: BreedGalleryRemoteDataSource {
    private let httpUtility: HTTPUtility

    init(httpUtility: HTTPUtility) {
        self.httpUtility = httpUtility
    }

    func fetchFlatBreedsList() async throws -> [String] {
        guard let url = APIConstants.DogCeo.breedsListURL() else {
            throw URLError(.badURL)
        }
        let request = URLRequest(url: url)
        let response = try await httpUtility.request(DogCeoFlatBreedListResponse.self, with: request)
        return response.message.sorted()
    }

    func fetchRandomImageURLs(breedName: String, count: Int) async throws -> [URL] {
        guard count > 0 else { return [] }

        guard let url = APIConstants.DogCeo.breedRandomImagesURL(breedName: breedName, count: count) else {
            throw URLError(.badURL)
        }

        let request = URLRequest(url: url)
        let response = try await httpUtility.request(DogCeoImageListResponse.self, with: request)
        return deduplicate(response.message.compactMap(URL.init(string:)))
    }

    func fetchAllImageURLs(breedName: String) async throws -> [URL] {
        guard let url = APIConstants.DogCeo.breedAllImagesListURL(breedName: breedName) else {
            throw URLError(.badURL)
        }

        let request = URLRequest(url: url)
        let response = try await httpUtility.request(DogCeoImageListResponse.self, with: request)
        return deduplicate(response.message.compactMap(URL.init(string:)))
    }

    private func deduplicate(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { seen.insert($0.absoluteString).inserted }
    }
}

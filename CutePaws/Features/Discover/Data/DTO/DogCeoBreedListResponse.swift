import Foundation

/// Response from `GET /api/breeds/list` — flat breed slugs.
struct DogCeoFlatBreedListResponse: Decodable, Sendable {
    let message: [String]
}

import Foundation

/// Dog CEO JSON where `message` is a list of strings (random image URLs, breed image URLs, or flat breed slugs).
struct DogCeoListResponse: Decodable, Sendable {
    let message: [String]
}

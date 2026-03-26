import Foundation

struct RandomDogImageResponse: Decodable, Sendable {
    let fileSizeBytes: Int
    let url: String
}


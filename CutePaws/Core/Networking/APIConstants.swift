import Foundation

enum APIConstants {
    enum DogCeo {
        static let scheme = "https"
        static let host = "dog.ceo"

        static func randomImagesURL(count: Int) -> URL? {
            var components = URLComponents()
            components.scheme = scheme
            components.host = host
            components.path = "/api/breeds/image/random/\(count)"
            return components.url
        }
    }

    enum RandomDog {
        // Reserved for future media support.
        static let videoFeedURL = URL(string: "https://random.dog/woof.json?include=mp4,webm,gif")!
    }
}

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
        static let scheme = "https"
        static let host = "random.dog"

        static func randomImageURL() -> URL? {
            var components = URLComponents()
            components.scheme = scheme
            components.host = host
            components.path = "/woof.json"
            components.queryItems = [
                URLQueryItem(name: "include", value: "jpeg,jpg,png")
            ]
            return components.url
        }

        static func randomVideoURL() -> URL? {
            var components = URLComponents()
            components.scheme = scheme
            components.host = host
            components.path = "/woof.json"
            components.queryItems = [
                URLQueryItem(name: "include", value: "mp4")
            ]
            return components.url
        }
    }
}

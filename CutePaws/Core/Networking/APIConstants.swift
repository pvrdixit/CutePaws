import Foundation

enum APIConstants {
    enum DogCeo {
        static let scheme = "https"
        static let host = "dog.ceo"
        static let imagesHost = "images.dog.ceo"

        static func randomImagesURL(count: Int) -> URL? {
            var components = URLComponents()
            components.scheme = scheme
            components.host = host
            components.path = "/api/breeds/image/random/\(count)"
            return components.url
        }

        static func breedsListAllURL() -> URL? {
            var components = URLComponents()
            components.scheme = scheme
            components.host = host
            components.path = "/api/breeds/list/all"
            return components.url
        }

        /// Flat breed slugs (`/api/breeds/list`).
        static func breedsListURL() -> URL? {
            var components = URLComponents()
            components.scheme = scheme
            components.host = host
            components.path = "/api/breeds/list"
            return components.url
        }

        /// Random images for a breed with no sub-breeds: `/api/breed/{breed}/images/random/{count}`
        static func breedRandomImagesURL(breedName: String, count: Int) -> URL? {
            guard count > 0 else { return nil }
            var components = URLComponents()
            components.scheme = scheme
            components.host = host
            let encodedBreed = breedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? breedName
            components.path = "/api/breed/\(encodedBreed)/images/random/\(count)"
            return components.url
        }

        /// All image URLs for a breed (no sub-breeds): `/api/breed/{breed}/images`
        static func breedAllImagesListURL(breedName: String) -> URL? {
            var components = URLComponents()
            components.scheme = scheme
            components.host = host
            let encodedBreed = breedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? breedName
            components.path = "/api/breed/\(encodedBreed)/images"
            return components.url
        }

        /// Stable persistence key: path segment after `breeds/` (e.g. `weimaraner/n02092339_642.jpg`).
        static func breedImageRelativePath(from imageURL: URL) -> String? {
            let path = imageURL.path
            guard let range = path.range(of: "/breeds/", options: .caseInsensitive) else { return nil }
            let suffix = String(path[range.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !suffix.isEmpty else { return nil }
            return suffix
        }

        /// Reconstructs `https://images.dog.ceo/breeds/{relativePath}` from a stored relative path.
        static func breedImageCDNURL(relativePath: String) -> URL? {
            var components = URLComponents()
            components.scheme = scheme
            components.host = imagesHost
            let trimmed = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !trimmed.isEmpty else { return nil }
            components.path = "/breeds/\(trimmed)"
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

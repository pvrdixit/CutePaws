import Foundation
import UIKit

/// Small shared in-memory cache to avoid repeated disk reads while SwiftUI re-renders.
final class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {}

    func image(forFilePath path: String?) -> UIImage? {
        guard let path, !path.isEmpty else { return nil }

        let key = NSString(string: path)
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let image = UIImage(contentsOfFile: path)
        if let image {
            cache.setObject(image, forKey: key)
        }
        return image
    }
}


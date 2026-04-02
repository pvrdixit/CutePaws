import Foundation

enum FavoriteMediaType: String, Codable, Sendable {
    case photo
    case video

    static func inferred(fromURL url: URL) -> FavoriteMediaType {
        let ext = url.pathExtension.lowercased()
        if ["mp4", "mov", "m4v", "avi", "webm"].contains(ext) {
            return .video
        }
        return .photo
    }
}

import Foundation

struct MediaItem: Identifiable, Equatable, Sendable {
    let remoteURL: URL
    let localFilePath: String?
    let aspectRatio: Double
    let createdAt: Date

    var id: String {
        remoteURL.absoluteString
    }
}

import Foundation

struct MediaItem: Identifiable, Equatable, Sendable {
    let remoteURL: URL
    let localFilePath: String?
    let aspectRatio: Double
    let source: MediaSource
    let createdAt: Date

    var id: String {
        remoteURL.absoluteString
    }
}

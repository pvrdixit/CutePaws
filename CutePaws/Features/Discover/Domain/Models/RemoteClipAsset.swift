import Foundation

/// API-hosted clip persisted locally (spotlight image or mini-moment video).
struct RemoteClipAsset: Identifiable, Equatable, Sendable {
    let remoteURL: URL
    let localFilePath: String?
    let fileSizeBytes: Int
    let createdAt: Date
    /// Set for spotlight stills; `nil` for mini-moment videos.
    let aspectRatio: Double?

    var id: String {
        remoteURL.absoluteString
    }
}

typealias SpotlightItem = RemoteClipAsset
typealias MiniMomentItem = RemoteClipAsset

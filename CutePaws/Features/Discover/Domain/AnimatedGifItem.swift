import Foundation

struct AnimatedGifItem: Identifiable, Equatable, Sendable {
    let remoteURL: URL
    let localFilePath: String?
    let fileSizeBytes: Int
    let createdAt: Date

    var id: String {
        remoteURL.absoluteString
    }
}


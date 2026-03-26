import Foundation

struct SpotlightItem: Identifiable, Equatable, Sendable {
    let remoteURL: URL
    let localFilePath: String?
    let fileSizeBytes: Int
    let aspectRatio: Double
    let createdAt: Date

    var id: String {
        remoteURL.absoluteString
    }
}


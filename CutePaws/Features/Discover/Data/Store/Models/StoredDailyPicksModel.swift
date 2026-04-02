import Foundation
import SwiftData

@Model
final class StoredMediaItem {
    @Attribute(.unique) var remoteURLString: String
    var sourceRaw: String
    var createdAt: Date
    var localFilePath: String?
    var aspectRatio: Double

    init(
        remoteURLString: String,
        sourceRaw: String,
        createdAt: Date,
        localFilePath: String?,
        aspectRatio: Double
    ) {
        self.remoteURLString = remoteURLString
        self.sourceRaw = sourceRaw
        self.createdAt = createdAt
        self.localFilePath = localFilePath
        self.aspectRatio = aspectRatio
    }
}

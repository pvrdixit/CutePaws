import Foundation
import SwiftData

@Model
final class StoredSpotlightItem {
    @Attribute(.unique) var remoteURLString: String
    var createdAt: Date
    var localFilePath: String?
    var fileSizeBytes: Int
    var aspectRatio: Double

    init(
        remoteURLString: String,
        createdAt: Date,
        localFilePath: String?,
        fileSizeBytes: Int,
        aspectRatio: Double
    ) {
        self.remoteURLString = remoteURLString
        self.createdAt = createdAt
        self.localFilePath = localFilePath
        self.fileSizeBytes = fileSizeBytes
        self.aspectRatio = aspectRatio
    }
}

import Foundation
import SwiftData

@Model
final class StoredMiniMomentItem {
    @Attribute(.unique) var remoteURLString: String
    var createdAt: Date
    var localFilePath: String?
    var fileSizeBytes: Int

    init(remoteURLString: String, createdAt: Date, localFilePath: String?, fileSizeBytes: Int) {
        self.remoteURLString = remoteURLString
        self.createdAt = createdAt
        self.localFilePath = localFilePath
        self.fileSizeBytes = fileSizeBytes
    }
}

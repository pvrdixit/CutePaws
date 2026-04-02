import Foundation
import SwiftData

@Model
final class StoredFavoriteItem {
    @Attribute(.unique) var sourceID: String
    var displayName: String
    var mediaTypeRaw: String
    var localFilePath: String?
    var orderID: Int64

    init(
        sourceID: String,
        displayName: String,
        mediaTypeRaw: String,
        localFilePath: String?,
        orderID: Int64
    ) {
        self.sourceID = sourceID
        self.displayName = displayName
        self.mediaTypeRaw = mediaTypeRaw
        self.localFilePath = localFilePath
        self.orderID = orderID
    }
}

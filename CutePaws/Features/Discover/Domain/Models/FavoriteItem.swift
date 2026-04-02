import Foundation

struct FavoriteItem: Identifiable, Equatable, Sendable {
    let sourceID: String
    let displayName: String
    let mediaType: FavoriteMediaType
    let localFilePath: String?
    let orderID: Int64

    var id: String {
        sourceID
    }
}

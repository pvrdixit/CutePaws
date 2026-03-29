import Foundation

struct DetailMediaItem: Identifiable, Equatable, Sendable {
    let id: String
    let sourceID: String
    let displayName: String
    let mediaType: FavoriteMediaType
    let imagePath: String?
}

enum ImageDetailFlow: Sendable {
    case dailyPicks
    case spotlight
    case miniMoments
}

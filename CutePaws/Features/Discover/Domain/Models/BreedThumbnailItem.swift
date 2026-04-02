import Foundation

struct BreedThumbnailItem: Identifiable, Equatable, Sendable {
    let breedName: String
    /// Empty when the row is for a breed without sub-breeds.
    let subBreedName: String
    let thumbnailImageData: Data
    let aspectRatio: Double
    let remoteSourceURL: URL
    let updatedAt: Date

    var id: String {
        Self.catalogKey(breedName: breedName, subBreedName: subBreedName)
    }

    static func catalogKey(breedName: String, subBreedName: String) -> String {
        if subBreedName.isEmpty {
            return breedName
        }
        return breedName + "\u{1e}" + subBreedName
    }
}

import Foundation

protocol FavoriteRepository {
    func loadFavorites() async -> [FavoriteItem]
    func isFavorite(sourceID: String) async -> Bool
    func addFavorite(
        sourceID: String,
        displayName: String,
        mediaType: FavoriteMediaType,
        sourceFilePath: String?
    ) async
    func removeFavorite(sourceID: String) async
}

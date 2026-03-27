import Foundation

@MainActor
final class FavoriteRepositoryImpl: FavoriteRepository {
    private let store: FavoriteStore
    private let mediaFileStorage: MediaFileStorage

    init(store: FavoriteStore, mediaFileStorage: MediaFileStorage) {
        self.store = store
        self.mediaFileStorage = mediaFileStorage
    }

    func loadFavorites() async -> [FavoriteItem] {
        await store.fetchItems()
    }

    func isFavorite(sourceID: String) async -> Bool {
        await store.contains(sourceID: sourceID)
    }

    func addFavorite(
        sourceID: String,
        displayName: String,
        mediaType: FavoriteMediaType,
        sourceFilePath: String?
    ) async {
        guard !(await store.contains(sourceID: sourceID)) else { return }
        guard
            let sourceFilePath,
            let data = FileManager.default.contents(atPath: sourceFilePath)
        else {
            return
        }

        let pathExtension = URL(fileURLWithPath: sourceFilePath).pathExtension
        let savedPath: String
        do {
            savedPath = try mediaFileStorage.saveImageData(data, suggestedPathExtension: pathExtension)
        } catch {
            return
        }
        let favorite = FavoriteItem(
            sourceID: sourceID,
            displayName: displayName,
            mediaType: mediaType,
            localFilePath: savedPath,
            orderID: Self.makeOrderID()
        )
        await store.save(favorite)
    }

    func removeFavorite(sourceID: String) async {
        await store.delete(sourceID: sourceID)
    }

    private static func makeOrderID() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}


import Foundation
import SwiftData

protocol FavoriteStore {
    func fetchItems() async -> [FavoriteItem]
    func contains(sourceID: String) async -> Bool
    func save(_ item: FavoriteItem) async
    func delete(sourceID: String) async
}

@MainActor
final class SwiftDataFavoriteStore: FavoriteStore {
    private let context: ModelContext
    private let fileStorage: MediaFileStorage

    init(container: ModelContainer, fileStorage: MediaFileStorage) {
        context = ModelContext(container)
        self.fileStorage = fileStorage
    }

    func fetchItems() async -> [FavoriteItem] {
        do {
            let descriptor = FetchDescriptor<StoredFavoriteItem>(
                sortBy: [SortDescriptor(\.orderID, order: .forward)]
            )
            let stored = try context.fetch(descriptor)
            return stored.compactMap(makeFavoriteItem)
        } catch {
            return []
        }
    }

    func contains(sourceID: String) async -> Bool {
        do {
            let descriptor = FetchDescriptor<StoredFavoriteItem>(
                predicate: #Predicate<StoredFavoriteItem> { $0.sourceID == sourceID }
            )
            return try !context.fetch(descriptor).isEmpty
        } catch {
            return false
        }
    }

    func save(_ item: FavoriteItem) async {
        guard !(await contains(sourceID: item.sourceID)) else { return }
        let stored = StoredFavoriteItem(
            sourceID: item.sourceID,
            displayName: item.displayName,
            mediaTypeRaw: item.mediaType.rawValue,
            localFilePath: fileStorage.fileReference(for: item.localFilePath),
            orderID: item.orderID
        )
        context.insert(stored)
        try? context.save()
    }

    func delete(sourceID: String) async {
        do {
            let descriptor = FetchDescriptor<StoredFavoriteItem>(
                predicate: #Predicate<StoredFavoriteItem> { $0.sourceID == sourceID }
            )
            let matches = try context.fetch(descriptor)
            for item in matches {
                if let path = fileStorage.filePath(for: item.localFilePath) {
                    fileStorage.removeFile(at: path)
                }
                context.delete(item)
            }
            try? context.save()
        } catch {
            return
        }
    }

    private func makeFavoriteItem(from stored: StoredFavoriteItem) -> FavoriteItem? {
        guard let mediaType = FavoriteMediaType(rawValue: stored.mediaTypeRaw) else { return nil }
        return FavoriteItem(
            sourceID: stored.sourceID,
            displayName: stored.displayName,
            mediaType: mediaType,
            localFilePath: fileStorage.filePath(for: stored.localFilePath),
            orderID: stored.orderID
        )
    }
}


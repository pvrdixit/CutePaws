import Foundation
import SwiftData

protocol AnimatedGifStore {
    func deleteInvalidItems() async
    func fetchItems(limit: Int) async -> [AnimatedGifItem]
    func fetchItemsSnapshot(limit: Int) -> [AnimatedGifItem]
    func itemCount() async -> Int
    func save(_ items: [AnimatedGifItem]) async
    func trimToLatest(maxCount: Int) async
}

@Model
final class StoredAnimatedGifItem {
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

@MainActor
final class SwiftDataAnimatedGifStore: AnimatedGifStore {
    private let context: ModelContext
    private let fileStorage: MediaFileStorage
    private let logger: AppLogger

    init(container: ModelContainer, fileStorage: MediaFileStorage, logger: AppLogger) {
        context = ModelContext(container)
        self.fileStorage = fileStorage
        self.logger = logger
    }

    func fetchItemsSnapshot(limit: Int) -> [AnimatedGifItem] {
        fetchItemsCore(limit: limit)
    }

    func deleteInvalidItems() async {
        do {
            let storedItems = try context.fetch(FetchDescriptor<StoredAnimatedGifItem>())
            var didDelete = false
            for item in storedItems where !isValid(item) {
                delete(item)
                didDelete = true
            }
            if didDelete { try context.save() }
            removeOrphanedFiles()
        } catch {
            logger.error("AnimatedGif SwiftData cleanup failed")
        }
    }

    func fetchItems(limit: Int) async -> [AnimatedGifItem] {
        fetchItemsCore(limit: limit)
    }

    private func fetchItemsCore(limit: Int) -> [AnimatedGifItem] {
        guard limit > 0 else { return [] }
        do {
            let descriptor = FetchDescriptor<StoredAnimatedGifItem>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            return try context.fetch(descriptor)
                .filter(isValid)
                .prefix(limit)
                .compactMap(makeItem(from:))
        } catch {
            logger.error("AnimatedGif SwiftData fetch failed")
            return []
        }
    }

    func itemCount() async -> Int {
        do {
            return try context.fetch(FetchDescriptor<StoredAnimatedGifItem>())
                .filter(isValid)
                .count
        } catch {
            logger.error("AnimatedGif SwiftData count failed")
            return 0
        }
    }

    func save(_ items: [AnimatedGifItem]) async {
        guard !items.isEmpty else { return }
        do {
            let existingItems = try context.fetch(FetchDescriptor<StoredAnimatedGifItem>())
            for item in existingItems where !isValid(item) {
                delete(item)
            }

            var existingURLs = Set(existingItems.filter(isValid).map(\.remoteURLString))
            for item in items {
                let remoteURLString = item.remoteURL.absoluteString
                if existingURLs.insert(remoteURLString).inserted {
                    context.insert(
                        StoredAnimatedGifItem(
                            remoteURLString: remoteURLString,
                            createdAt: item.createdAt,
                            localFilePath: fileStorage.fileReference(for: item.localFilePath),
                            fileSizeBytes: item.fileSizeBytes
                        )
                    )
                } else if let path = item.localFilePath {
                    fileStorage.removeFile(at: path)
                }
            }

            try context.save()
            removeOrphanedFiles()
        } catch {
            for item in items {
                if let path = item.localFilePath {
                    fileStorage.removeFile(at: path)
                }
            }
            logger.error("AnimatedGif SwiftData save failed")
        }
    }

    func trimToLatest(maxCount: Int) async {
        guard maxCount > 0 else { return }
        do {
            let descriptor = FetchDescriptor<StoredAnimatedGifItem>(
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
            let items = try context.fetch(descriptor).filter(isValid)
            guard items.count > maxCount else { return }
            for item in items.prefix(items.count - maxCount) {
                delete(item)
            }
            try context.save()
            removeOrphanedFiles()
        } catch {
            logger.error("AnimatedGif SwiftData trim failed")
        }
    }

    private func makeItem(from stored: StoredAnimatedGifItem) -> AnimatedGifItem? {
        guard let url = URL(string: stored.remoteURLString) else { return nil }
        return AnimatedGifItem(
            remoteURL: url,
            localFilePath: fileStorage.filePath(for: stored.localFilePath),
            fileSizeBytes: stored.fileSizeBytes,
            createdAt: stored.createdAt
        )
    }

    private func isValid(_ item: StoredAnimatedGifItem) -> Bool {
        fileStorage.fileExists(at: fileStorage.filePath(for: item.localFilePath))
    }

    private func delete(_ item: StoredAnimatedGifItem) {
        if let path = fileStorage.filePath(for: item.localFilePath) {
            fileStorage.removeFile(at: path)
        }
        context.delete(item)
    }

    private func removeOrphanedFiles() {
        guard let storedItems = try? context.fetch(FetchDescriptor<StoredAnimatedGifItem>()) else {
            return
        }
        let referencedPaths = Set(
            storedItems.compactMap { fileStorage.filePath(for: $0.localFilePath) }.filter { !$0.isEmpty }
        )
        fileStorage.removeOrphanedFiles(referencedPaths: referencedPaths)
    }
}


import Foundation
import SwiftData

protocol MiniMomentStore {
    func deleteInvalidItems() async
    func fetchItems(limit: Int) async -> [MiniMomentItem]
    func fetchItemsSnapshot(limit: Int) -> [MiniMomentItem]
    func itemCount() async -> Int
    func save(_ items: [MiniMomentItem]) async
    func trimToLatest(maxCount: Int) async
}

@MainActor
final class SwiftDataMiniMomentStore: MiniMomentStore {
    private let context: ModelContext
    private let fileStorage: MediaFileStorage
    private let logger: AppLogger

    init(container: ModelContainer, fileStorage: MediaFileStorage, logger: AppLogger) {
        context = ModelContext(container)
        self.fileStorage = fileStorage
        self.logger = logger
    }

    func fetchItemsSnapshot(limit: Int) -> [MiniMomentItem] {
        fetchItemsCore(limit: limit)
    }

    func deleteInvalidItems() async {
        do {
            let storedItems = try context.fetch(FetchDescriptor<StoredMiniMomentItem>())
            var didDelete = false
            for item in storedItems where !isValid(item) {
                delete(item)
                didDelete = true
            }
            if didDelete { try context.save() }
            removeOrphanedFiles()
        } catch {
            logger.error("MiniMoment SwiftData cleanup failed")
        }
    }

    func fetchItems(limit: Int) async -> [MiniMomentItem] {
        fetchItemsCore(limit: limit)
    }

    private func fetchItemsCore(limit: Int) -> [MiniMomentItem] {
        guard limit > 0 else { return [] }
        do {
            let descriptor = FetchDescriptor<StoredMiniMomentItem>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            return try context.fetch(descriptor)
                .filter(isValid)
                .prefix(limit)
                .compactMap(makeItem(from:))
        } catch {
            logger.error("MiniMoment SwiftData fetch failed")
            return []
        }
    }

    func itemCount() async -> Int {
        do {
            return try context.fetch(FetchDescriptor<StoredMiniMomentItem>())
                .filter(isValid)
                .count
        } catch {
            logger.error("MiniMoment SwiftData count failed")
            return 0
        }
    }

    func save(_ items: [MiniMomentItem]) async {
        guard !items.isEmpty else { return }
        do {
            let existingItems = try context.fetch(FetchDescriptor<StoredMiniMomentItem>())
            for item in existingItems where !isValid(item) {
                delete(item)
            }

            var existingURLs = Set(existingItems.filter(isValid).map(\.remoteURLString))
            for item in items {
                let remoteURLString = item.remoteURL.absoluteString
                if existingURLs.insert(remoteURLString).inserted {
                    context.insert(
                        StoredMiniMomentItem(
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
            logger.error("MiniMoment SwiftData save failed")
        }
    }

    func trimToLatest(maxCount: Int) async {
        guard maxCount > 0 else { return }
        do {
            let descriptor = FetchDescriptor<StoredMiniMomentItem>(
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
            logger.error("MiniMoment SwiftData trim failed")
        }
    }

    private func makeItem(from stored: StoredMiniMomentItem) -> MiniMomentItem? {
        guard let url = URL(string: stored.remoteURLString) else { return nil }
        return MiniMomentItem(
            remoteURL: url,
            localFilePath: fileStorage.filePath(for: stored.localFilePath),
            fileSizeBytes: stored.fileSizeBytes,
            createdAt: stored.createdAt,
            aspectRatio: nil
        )
    }

    private func isValid(_ item: StoredMiniMomentItem) -> Bool {
        fileStorage.fileExists(at: fileStorage.filePath(for: item.localFilePath))
    }

    private func delete(_ item: StoredMiniMomentItem) {
        if let path = fileStorage.filePath(for: item.localFilePath) {
            fileStorage.removeFile(at: path)
        }
        context.delete(item)
    }

    private func removeOrphanedFiles() {
        guard let storedItems = try? context.fetch(FetchDescriptor<StoredMiniMomentItem>()) else {
            return
        }
        let referencedPaths = Set(
            storedItems.compactMap { fileStorage.filePath(for: $0.localFilePath) }.filter { !$0.isEmpty }
        )
        fileStorage.removeOrphanedFiles(referencedPaths: referencedPaths)
    }
}


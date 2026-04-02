import Foundation
import SwiftData

protocol SpotlightStore {
    func deleteInvalidItems() async
    func fetchItems(limit: Int) async -> [SpotlightItem]
    func itemCount() async -> Int
    func save(_ items: [SpotlightItem]) async
    func trimToLatest(maxCount: Int) async
}

@Model
final class StoredSpotlightItem {
    @Attribute(.unique) var remoteURLString: String
    var createdAt: Date
    var localFilePath: String?
    var fileSizeBytes: Int
    var aspectRatio: Double

    init(
        remoteURLString: String,
        createdAt: Date,
        localFilePath: String?,
        fileSizeBytes: Int,
        aspectRatio: Double
    ) {
        self.remoteURLString = remoteURLString
        self.createdAt = createdAt
        self.localFilePath = localFilePath
        self.fileSizeBytes = fileSizeBytes
        self.aspectRatio = aspectRatio
    }
}

@MainActor
final class SwiftDataSpotlightStore: SpotlightStore {
    private let context: ModelContext
    private let fileStorage: MediaFileStorage
    private let logger: AppLogger

    init(container: ModelContainer, fileStorage: MediaFileStorage, logger: AppLogger) {
        context = ModelContext(container)
        self.fileStorage = fileStorage
        self.logger = logger
    }

    func fetchItemsSnapshot(limit: Int) -> [SpotlightItem] {
        fetchItemsCore(limit: limit, tag: "fetchItemsSnapshot")
    }

    func deleteInvalidItems() async {
        do {
            let storedItems = try context.fetch(FetchDescriptor<StoredSpotlightItem>())
            var didDelete = false

            for item in storedItems where !isValid(item) {
                delete(item)
                didDelete = true
            }

            if didDelete {
                try context.save()
            }
            removeOrphanedFiles()
        } catch {
            logger.error("Spotlight SwiftData cleanup failed")
        }
    }

    func fetchItems(limit: Int) async -> [SpotlightItem] {
        fetchItemsCore(limit: limit, tag: "fetchItems")
    }

    private func fetchItemsCore(limit: Int, tag: String) -> [SpotlightItem] {
        guard limit > 0 else { return [] }

        do {
            let descriptor = FetchDescriptor<StoredSpotlightItem>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let storedItems = try context.fetch(descriptor)
            let items = storedItems
                .filter(isValid)
                .prefix(limit)
                .compactMap(makeSpotlightItem(from:))
            debugLog("\(tag) limit=\(limit) storedRows=\(storedItems.count) returned=\(items.count)")
            return items
        } catch {
            logger.error("Spotlight SwiftData fetch failed", metadata: ["tag": tag])
            return []
        }
    }

    func itemCount() async -> Int {
        do {
            return try context.fetch(FetchDescriptor<StoredSpotlightItem>())
                .filter(isValid)
                .count
        } catch {
            logger.error("Spotlight SwiftData count failed")
            return 0
        }
    }

    func save(_ items: [SpotlightItem]) async {
        guard !items.isEmpty else { return }

        do {
            let existingItems = try context.fetch(FetchDescriptor<StoredSpotlightItem>())
            for item in existingItems where !isValid(item) {
                delete(item)
            }

            var existingURLs = Set(existingItems.filter(isValid).map(\.remoteURLString))

            for item in items {
                let remoteURLString = item.remoteURL.absoluteString

                if existingURLs.insert(remoteURLString).inserted {
                    context.insert(
                        StoredSpotlightItem(
                            remoteURLString: remoteURLString,
                            createdAt: item.createdAt,
                            localFilePath: fileStorage.fileReference(for: item.localFilePath),
                            fileSizeBytes: item.fileSizeBytes,
                            aspectRatio: item.aspectRatio ?? 1.5
                        )
                    )
                } else if let localFilePath = item.localFilePath {
                    fileStorage.removeFile(at: localFilePath)
                }
            }

            try context.save()
            removeOrphanedFiles()
        } catch {
            for item in items {
                if let localFilePath = item.localFilePath {
                    fileStorage.removeFile(at: localFilePath)
                }
            }
            logger.error("Spotlight SwiftData save failed", metadata: ["count": "\(items.count)"])
        }
    }

    func trimToLatest(maxCount: Int) async {
        guard maxCount > 0 else { return }

        do {
            let descriptor = FetchDescriptor<StoredSpotlightItem>(
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
            logger.error("Spotlight SwiftData trim failed", metadata: ["maxCount": "\(maxCount)"])
        }
    }

    private func makeSpotlightItem(from item: StoredSpotlightItem) -> SpotlightItem? {
        guard let url = URL(string: item.remoteURLString) else { return nil }

        return SpotlightItem(
            remoteURL: url,
            localFilePath: fileStorage.filePath(for: item.localFilePath),
            fileSizeBytes: item.fileSizeBytes,
            createdAt: item.createdAt,
            aspectRatio: item.aspectRatio
        )
    }

    private func isValid(_ item: StoredSpotlightItem) -> Bool {
        fileStorage.fileExists(at: fileStorage.filePath(for: item.localFilePath))
    }

    private func delete(_ item: StoredSpotlightItem) {
        if let localFilePath = fileStorage.filePath(for: item.localFilePath) {
            fileStorage.removeFile(at: localFilePath)
        }
        context.delete(item)
    }

    private func removeOrphanedFiles() {
        guard let storedItems = try? context.fetch(FetchDescriptor<StoredSpotlightItem>()) else {
            return
        }

        let referencedPaths = Set(
            storedItems
                .compactMap { fileStorage.filePath(for: $0.localFilePath) }
                .filter { !$0.isEmpty }
        )
        fileStorage.removeOrphanedFiles(referencedPaths: referencedPaths)
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("SwiftDataSpotlightStore:", message)
        #endif
    }
}


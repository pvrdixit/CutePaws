import Foundation
import SwiftData

protocol DiscoverStore {
    func deleteInvalidItems() async
    func fetchItems(limit: Int) async -> [MediaItem]
    func itemCount() async -> Int
    func save(_ items: [MediaItem]) async
    func trimToLatest(maxCount: Int) async
}

@Model
final class StoredMediaItem {
    @Attribute(.unique) var remoteURLString: String
    var sourceRaw: String
    var createdAt: Date
    var localFilePath: String?
    var aspectRatio: Double

    init(
        remoteURLString: String,
        sourceRaw: String,
        createdAt: Date,
        localFilePath: String?,
        aspectRatio: Double
    ) {
        self.remoteURLString = remoteURLString
        self.sourceRaw = sourceRaw
        self.createdAt = createdAt
        self.localFilePath = localFilePath
        self.aspectRatio = aspectRatio
    }
}

@MainActor
final class SwiftDataDiscoverStore: DiscoverStore {
    private let context: ModelContext
    private let fileStorage: MediaFileStorage
    private let logger: AppLogger

    init(container: ModelContainer, fileStorage: MediaFileStorage, logger: AppLogger) {
        context = ModelContext(container)
        self.fileStorage = fileStorage
        self.logger = logger
    }

    func fetchItemsSnapshot(limit: Int) -> [MediaItem] {
        fetchItemsCore(limit: limit, tag: "fetchItemsSnapshot")
    }

    func deleteInvalidItems() async {
        do {
            let storedItems = try context.fetch(FetchDescriptor<StoredMediaItem>())
            var didDelete = false
            var deletedCount = 0

            for item in storedItems where !isValid(item) {
                debugLog(
                    "deleteInvalidItems removing url=\(item.remoteURLString) reason=\(invalidReason(for: item)) reference=\(item.localFilePath ?? "nil") resolvedPath=\(fileStorage.filePath(for: item.localFilePath) ?? "nil")"
                )
                delete(item)
                didDelete = true
                deletedCount += 1
            }

            if didDelete {
                try context.save()
            }

            debugLog("deleteInvalidItems storedRows=\(storedItems.count) deleted=\(deletedCount)")
            removeOrphanedFiles()
        } catch {
            logger.error("SwiftData cleanup failed")
            debugLog("deleteInvalidItems failed")
        }
    }

    func fetchItems(limit: Int) async -> [MediaItem] {
        fetchItemsCore(limit: limit, tag: "fetchItems")
    }

    private func fetchItemsCore(limit: Int, tag: String) -> [MediaItem] {
        guard limit > 0 else { return [] }

        do {
            let descriptor = FetchDescriptor<StoredMediaItem>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let storedItems = try context.fetch(descriptor)
            let items = storedItems
                .filter(isValid)
                .prefix(limit)
                .compactMap(makeMediaItem(from:))

            debugLog("\(tag) limit=\(limit) storedRows=\(storedItems.count) returned=\(items.count)")
            return items
        } catch {
            logger.error("SwiftData fetch failed", metadata: ["tag": tag])
            debugLog("\(tag) failed")
            return []
        }
    }

    func itemCount() async -> Int {
        do {
            let count = try context.fetch(FetchDescriptor<StoredMediaItem>())
                .filter(isValid)
                .count
            debugLog("itemCount -> \(count)")
            return count
        } catch {
            logger.error("SwiftData count failed")
            debugLog("itemCount failed")
            return 0
        }
    }

    func save(_ items: [MediaItem]) async {
        guard !items.isEmpty else { return }

        do {
            let existingItems = try context.fetch(FetchDescriptor<StoredMediaItem>())
            let existingValidCount = existingItems.filter(isValid).count
            var insertedCount = 0
            var duplicatePathDeletes = 0

            for item in existingItems where !isValid(item) {
                delete(item)
            }

            let validExistingItems = existingItems.filter(isValid)
            var existingURLs = Set(validExistingItems.map(\.remoteURLString))

            for item in items {
                let remoteURLString = item.remoteURL.absoluteString

                if existingURLs.insert(remoteURLString).inserted {
                    context.insert(
                        StoredMediaItem(
                            remoteURLString: remoteURLString,
                            sourceRaw: item.source.rawValue,
                            createdAt: item.createdAt,
                            localFilePath: fileStorage.fileReference(for: item.localFilePath),
                            aspectRatio: item.aspectRatio
                        )
                    )
                    insertedCount += 1
                } else if let localFilePath = item.localFilePath {
                    fileStorage.removeFile(at: localFilePath)
                    duplicatePathDeletes += 1
                }
            }

            try context.save()
            debugLog(
                "save incoming=\(items.count) existingValid=\(existingValidCount) inserted=\(insertedCount) duplicatePathDeletes=\(duplicatePathDeletes)"
            )
            removeOrphanedFiles()
        } catch {
            for item in items {
                if let localFilePath = item.localFilePath {
                    fileStorage.removeFile(at: localFilePath)
                }
            }
            logger.error("SwiftData save failed", metadata: ["count": "\(items.count)"])
            debugLog("save failed incoming=\(items.count)")
        }
    }

    func trimToLatest(maxCount: Int) async {
        guard maxCount > 0 else { return }

        do {
            let descriptor = FetchDescriptor<StoredMediaItem>(
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
            let storedItems = try context.fetch(descriptor)
            let supportedItems = storedItems.filter(isValid)
            let deleteCount = max(0, supportedItems.count - maxCount)

            guard supportedItems.count > maxCount else { return }

            for item in supportedItems.prefix(deleteCount) {
                delete(item)
            }

            try context.save()
            debugLog("trimToLatest before=\(supportedItems.count) maxCount=\(maxCount) deleted=\(deleteCount)")
            removeOrphanedFiles()
        } catch {
            logger.error("SwiftData trim failed", metadata: ["maxCount": "\(maxCount)"])
            debugLog("trimToLatest failed maxCount=\(maxCount)")
        }
    }

    private func makeMediaItem(from item: StoredMediaItem) -> MediaItem? {
        guard
            item.sourceRaw == MediaSource.dogCeo.rawValue,
            let url = URL(string: item.remoteURLString),
            let source = MediaSource(rawValue: item.sourceRaw)
        else {
            return nil
        }

        return MediaItem(
            remoteURL: url,
            localFilePath: fileStorage.filePath(for: item.localFilePath),
            aspectRatio: item.aspectRatio,
            source: source,
            createdAt: item.createdAt
        )
    }

    private func isValid(_ item: StoredMediaItem) -> Bool {
        item.sourceRaw == MediaSource.dogCeo.rawValue
        && fileStorage.fileExists(at: fileStorage.filePath(for: item.localFilePath))
    }

    private func delete(_ item: StoredMediaItem) {
        if let localFilePath = fileStorage.filePath(for: item.localFilePath) {
            fileStorage.removeFile(at: localFilePath)
        }
        context.delete(item)
    }

    private func removeOrphanedFiles() {
        guard let storedItems = try? context.fetch(FetchDescriptor<StoredMediaItem>()) else {
            debugLog("removeOrphanedFiles skipped because fetch failed")
            return
        }

        let referencedPaths = Set(
            storedItems
                .compactMap { fileStorage.filePath(for: $0.localFilePath) }
                .filter { !$0.isEmpty }
        )

        debugLog("removeOrphanedFiles referencedPaths=\(referencedPaths.count)")
        fileStorage.removeOrphanedFiles(referencedPaths: referencedPaths)
    }

    private func invalidReason(for item: StoredMediaItem) -> String {
        if item.sourceRaw != MediaSource.dogCeo.rawValue {
            return "unsupportedSource"
        }

        if !fileStorage.fileExists(at: fileStorage.filePath(for: item.localFilePath)) {
            return "missingFile"
        }

        return "unknown"
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("SwiftDataDiscoverStore:", message)
        #endif
    }
}

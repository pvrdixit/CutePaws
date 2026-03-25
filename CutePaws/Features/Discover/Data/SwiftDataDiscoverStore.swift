import Foundation
import SwiftData

@Model
final class StoredMediaItem {
    @Attribute(.unique) var remoteURLString: String
    var sourceRaw: String
    var createdAt: Date
    @Attribute(.externalStorage) var imageData: Data
    var aspectRatio: Double

    init(
        remoteURLString: String,
        sourceRaw: String,
        createdAt: Date,
        imageData: Data,
        aspectRatio: Double
    ) {
        self.remoteURLString = remoteURLString
        self.sourceRaw = sourceRaw
        self.createdAt = createdAt
        self.imageData = imageData
        self.aspectRatio = aspectRatio
    }
}

@MainActor
final class SwiftDataDiscoverStore {
    private let context: ModelContext
    private let logger: AppLogger

    init(container: ModelContainer, logger: AppLogger) {
        context = ModelContext(container)
        self.logger = logger
    }

    func deleteUnsupportedItems() async {
        do {
            let storedItems = try context.fetch(FetchDescriptor<StoredMediaItem>())
            var didDelete = false

            for item in storedItems where item.sourceRaw != MediaSource.dogCeo.rawValue {
                context.delete(item)
                didDelete = true
            }

            if didDelete {
                try context.save()
            }
        } catch {
            logger.error("SwiftData cleanup failed")
        }
    }

    func fetchItems(limit: Int) async -> [MediaItem] {
        guard limit > 0 else { return [] }

        do {
            let descriptor = FetchDescriptor<StoredMediaItem>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let storedItems = try context.fetch(descriptor)
            return storedItems
                .filter { $0.sourceRaw == MediaSource.dogCeo.rawValue }
                .prefix(limit)
                .compactMap(Self.makeMediaItem(from:))
        } catch {
            logger.error("SwiftData fetch failed")
            return []
        }
    }

    func itemCount() async -> Int {
        do {
            return try context.fetch(FetchDescriptor<StoredMediaItem>())
                .filter { $0.sourceRaw == MediaSource.dogCeo.rawValue }
                .count
        } catch {
            logger.error("SwiftData count failed")
            return 0
        }
    }

    func save(_ items: [MediaItem]) async {
        guard !items.isEmpty else { return }

        do {
            let existingItems = try context.fetch(FetchDescriptor<StoredMediaItem>())
            var existingURLs = Set(existingItems.map(\.remoteURLString))

            for item in items where existingURLs.insert(item.remoteURL.absoluteString).inserted {
                context.insert(
                    StoredMediaItem(
                        remoteURLString: item.remoteURL.absoluteString,
                        sourceRaw: item.source.rawValue,
                        createdAt: item.createdAt,
                        imageData: item.imageData,
                        aspectRatio: item.aspectRatio
                    )
                )
            }

            try context.save()
        } catch {
            logger.error("SwiftData save failed", metadata: ["count": "\(items.count)"])
        }
    }

    func trimToLatest(maxCount: Int) async {
        guard maxCount > 0 else { return }

        do {
            let descriptor = FetchDescriptor<StoredMediaItem>(
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
            let storedItems = try context.fetch(descriptor)
            let supportedItems = storedItems.filter { $0.sourceRaw == MediaSource.dogCeo.rawValue }

            guard supportedItems.count > maxCount else { return }

            for item in supportedItems.prefix(supportedItems.count - maxCount) {
                context.delete(item)
            }

            try context.save()
        } catch {
            logger.error("SwiftData trim failed", metadata: ["maxCount": "\(maxCount)"])
        }
    }

    private static func makeMediaItem(from item: StoredMediaItem) -> MediaItem? {
        guard
            item.sourceRaw == MediaSource.dogCeo.rawValue,
            let url = URL(string: item.remoteURLString),
            let source = MediaSource(rawValue: item.sourceRaw)
        else {
            return nil
        }

        return MediaItem(
            remoteURL: url,
            imageData: item.imageData,
            aspectRatio: item.aspectRatio,
            source: source,
            createdAt: item.createdAt
        )
    }
}

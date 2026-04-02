import Foundation
import SwiftData

protocol BreedThumbnailStore {
    func deleteInvalidItems() async
    func existingCatalogKeys() async -> Set<String>
    func save(_ items: [BreedThumbnailItem]) async
    func fetchAllSnapshot() async -> [BreedThumbnailItem]
}

@MainActor
final class SwiftDataBreedThumbnailStore: BreedThumbnailStore {
    private let context: ModelContext
    private let logger: AppLogger

    init(container: ModelContainer, logger: AppLogger) {
        context = ModelContext(container)
        self.logger = logger
    }

    func deleteInvalidItems() async {
        do {
            let stored = try context.fetch(FetchDescriptor<StoredBreedThumbnailItem>())
            var didDelete = false
            for item in stored where !isValid(item) {
                context.delete(item)
                didDelete = true
            }
            if didDelete { try context.save() }
        } catch {
            logger.error("BreedThumbnail SwiftData cleanup failed")
        }
    }

    func existingCatalogKeys() async -> Set<String> {
        do {
            let stored = try context.fetch(FetchDescriptor<StoredBreedThumbnailItem>())
            return Set(stored.filter(isValid).map(\.catalogKey))
        } catch {
            logger.error("BreedThumbnail SwiftData fetch keys failed")
            return []
        }
    }

    func save(_ items: [BreedThumbnailItem]) async {
        guard !items.isEmpty else { return }
        do {
            let stored = try context.fetch(FetchDescriptor<StoredBreedThumbnailItem>())
            for item in stored where !isValid(item) {
                context.delete(item)
            }

            let valid = stored.filter(isValid)
            var byKey = Dictionary(uniqueKeysWithValues: valid.map { ($0.catalogKey, $0) })

            for item in items {
                let key = item.id
                if let existing = byKey[key] {
                    existing.breedName = item.breedName
                    existing.subBreedName = item.subBreedName
                    existing.thumbnailImageData = item.thumbnailImageData
                    existing.aspectRatio = item.aspectRatio
                    existing.remoteURLString = item.remoteSourceURL.absoluteString
                    existing.sourceRaw = DogCeoPersistedSource.rawValue
                    existing.updatedAt = item.updatedAt
                } else {
                    let row = StoredBreedThumbnailItem(
                        catalogKey: key,
                        breedName: item.breedName,
                        subBreedName: item.subBreedName,
                        thumbnailImageData: item.thumbnailImageData,
                        aspectRatio: item.aspectRatio,
                        remoteURLString: item.remoteSourceURL.absoluteString,
                        sourceRaw: DogCeoPersistedSource.rawValue,
                        updatedAt: item.updatedAt
                    )
                    context.insert(row)
                    byKey[key] = row
                }
            }

            try context.save()
        } catch {
            logger.error("BreedThumbnail SwiftData save failed", metadata: ["count": "\(items.count)"])
        }
    }

    func fetchAllSnapshot() async -> [BreedThumbnailItem] {
        do {
            let descriptor = FetchDescriptor<StoredBreedThumbnailItem>(
                sortBy: [
                    SortDescriptor(\.breedName, order: .forward),
                    SortDescriptor(\.subBreedName, order: .forward)
                ]
            )
            let stored = try context.fetch(descriptor)
            return stored.filter(isValid).compactMap(domainItem(from:))
        } catch {
            logger.error("BreedThumbnail SwiftData fetch snapshot failed")
            return []
        }
    }

    private func isValid(_ item: StoredBreedThumbnailItem) -> Bool {
        item.sourceRaw == DogCeoPersistedSource.rawValue
            && !item.thumbnailImageData.isEmpty
            && !item.catalogKey.isEmpty
    }

    private func domainItem(from stored: StoredBreedThumbnailItem) -> BreedThumbnailItem? {
        guard let url = URL(string: stored.remoteURLString) else {
            return nil
        }
        return BreedThumbnailItem(
            breedName: stored.breedName,
            subBreedName: stored.subBreedName,
            thumbnailImageData: stored.thumbnailImageData,
            aspectRatio: stored.aspectRatio,
            remoteSourceURL: url,
            updatedAt: stored.updatedAt
        )
    }
}

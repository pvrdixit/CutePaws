import Foundation
import SwiftData

protocol BreedCatalogStore {
    func loadPersistedBreedNames() async -> [String]?
    func saveBreedNames(_ names: [String]) async
    func isThumbnailBootstrapCompleted() async -> Bool
    func markThumbnailBootstrapCompleted() async
}

private enum BreedCatalogCodec {
    static func encode(_ names: [String]) throws -> Data {
        try JSONEncoder().encode(names)
    }

    static func decode(_ data: Data) throws -> [String] {
        try JSONDecoder().decode([String].self, from: data)
    }
}

@MainActor
final class SwiftDataBreedCatalogStore: BreedCatalogStore {
    /// New key so installs that used hierarchical `/breeds/list/all` re-bootstrap thumbnails for flat `/breeds/list`.
    private static let singletonKey = "breedExploreFlat"

    private let context: ModelContext
    private let logger: AppLogger

    init(container: ModelContainer, logger: AppLogger) {
        context = ModelContext(container)
        self.logger = logger
    }

    func loadPersistedBreedNames() async -> [String]? {
        do {
            let key = Self.singletonKey
            let predicate = #Predicate<StoredBreedExploreMetadata> { $0.singletonKey == key }
            var descriptor = FetchDescriptor<StoredBreedExploreMetadata>(predicate: predicate)
            descriptor.fetchLimit = 1
            guard let row = try context.fetch(descriptor).first,
                  let data = row.catalogPayload
            else {
                return nil
            }
            return try BreedCatalogCodec.decode(data)
        } catch {
            logger.error("Breed catalog load failed")
            return nil
        }
    }

    func saveBreedNames(_ names: [String]) async {
        do {
            let data = try BreedCatalogCodec.encode(names)
            let key = Self.singletonKey
            let predicate = #Predicate<StoredBreedExploreMetadata> { $0.singletonKey == key }
            var descriptor = FetchDescriptor<StoredBreedExploreMetadata>(predicate: predicate)
            descriptor.fetchLimit = 1
            if let existing = try context.fetch(descriptor).first {
                existing.catalogPayload = data
            } else {
                context.insert(
                    StoredBreedExploreMetadata(
                        singletonKey: key,
                        catalogPayload: data,
                        thumbnailBootstrapCompleted: false
                    )
                )
            }
            try context.save()
        } catch {
            logger.error("Breed catalog save failed")
        }
    }

    func isThumbnailBootstrapCompleted() async -> Bool {
        do {
            let key = Self.singletonKey
            let predicate = #Predicate<StoredBreedExploreMetadata> { $0.singletonKey == key }
            var descriptor = FetchDescriptor<StoredBreedExploreMetadata>(predicate: predicate)
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.thumbnailBootstrapCompleted ?? false
        } catch {
            logger.error("Breed catalog bootstrap flag read failed")
            return false
        }
    }

    func markThumbnailBootstrapCompleted() async {
        do {
            let key = Self.singletonKey
            let predicate = #Predicate<StoredBreedExploreMetadata> { $0.singletonKey == key }
            var descriptor = FetchDescriptor<StoredBreedExploreMetadata>(predicate: predicate)
            descriptor.fetchLimit = 1
            guard let row = try context.fetch(descriptor).first else {
                logger.error("Breed catalog mark complete: missing metadata row")
                return
            }
            row.thumbnailBootstrapCompleted = true
            try context.save()
        } catch {
            logger.error("Breed catalog mark complete failed")
        }
    }
}

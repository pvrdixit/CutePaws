import Foundation
import SwiftData

protocol BreedGalleryStore {
    /// Drops legacy `StoredBreedGalleryItem` rows whose files are missing or invalid.
    func deleteInvalidItems() async
}

@MainActor
final class SwiftDataBreedGalleryStore: BreedGalleryStore {
    private let context: ModelContext
    private let fileStorage: MediaFileStorage
    private let logger: AppLogger

    init(container: ModelContainer, fileStorage: MediaFileStorage, logger: AppLogger) {
        context = ModelContext(container)
        self.fileStorage = fileStorage
        self.logger = logger
    }

    func deleteInvalidItems() async {
        do {
            let storedItems = try context.fetch(FetchDescriptor<StoredBreedGalleryItem>())
            var didDelete = false
            for item in storedItems where !isValid(item) {
                delete(item)
                didDelete = true
            }
            if didDelete { try context.save() }
            removeOrphanedFiles()
        } catch {
            logger.error("BreedGallery SwiftData cleanup failed")
        }
    }

    private func isValid(_ item: StoredBreedGalleryItem) -> Bool {
        item.sourceRaw == DogCeoPersistedSource.rawValue
            && fileStorage.fileExists(at: fileStorage.filePath(for: item.localFilePath))
    }

    private func delete(_ item: StoredBreedGalleryItem) {
        if let path = fileStorage.filePath(for: item.localFilePath) {
            fileStorage.removeFile(at: path)
        }
        context.delete(item)
    }

    private func removeOrphanedFiles() {
        guard let storedItems = try? context.fetch(FetchDescriptor<StoredBreedGalleryItem>()) else { return }
        let referencedPaths = Set(
            storedItems.compactMap { fileStorage.filePath(for: $0.localFilePath) }.filter { !$0.isEmpty }
        )
        fileStorage.removeOrphanedFiles(referencedPaths: referencedPaths)
    }
}

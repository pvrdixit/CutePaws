import Foundation
import SwiftData

struct BreedExploreGalleryPersistedRow: Equatable, Sendable {
    let relativeImagePath: String
    let localFilePath: String?
    let aspectRatio: Double
    let qualityRejected: Bool
    let createdAt: Date
}

@MainActor
protocol BreedExploreGalleryStore {
    func deleteInvalidItems() async
    func loadRows(galleryKey: String) async -> [BreedExploreGalleryPersistedRow]
    func saveAccepted(
        galleryKey: String,
        relativeImagePath: String,
        localFilePath: String,
        aspectRatio: Double
    ) async
    func markQualityRejected(galleryKey: String, relativeImagePath: String) async
}

@MainActor
final class SwiftDataBreedExploreGalleryStore: BreedExploreGalleryStore {
    private let context: ModelContext
    private let fileStorage: MediaFileStorage
    private let logger: AppLogger

    init(container: ModelContainer, fileStorage: MediaFileStorage, logger: AppLogger) {
        context = ModelContext(container)
        self.fileStorage = fileStorage
        self.logger = logger
    }

    static func makeStorageID(galleryKey: String, relativeImagePath: String) -> String {
        galleryKey + "\u{1f}" + relativeImagePath
    }

    func deleteInvalidItems() async {
        do {
            let stored = try context.fetch(FetchDescriptor<StoredBreedExploreGalleryImage>())
            var didDelete = false
            for item in stored where !isValid(item) {
                delete(item)
                didDelete = true
            }
            if didDelete { try context.save() }
            removeOrphanedFiles()
        } catch {
            logger.error("Breed explore gallery SwiftData cleanup failed")
        }
    }

    func loadRows(galleryKey: String) async -> [BreedExploreGalleryPersistedRow] {
        do {
            let predicate = #Predicate<StoredBreedExploreGalleryImage> { $0.galleryKey == galleryKey }
            let descriptor = FetchDescriptor<StoredBreedExploreGalleryImage>(predicate: predicate)
            let rows = try context.fetch(descriptor)
            return rows.map {
                BreedExploreGalleryPersistedRow(
                    relativeImagePath: $0.relativeImagePath,
                    localFilePath: $0.localFilePath,
                    aspectRatio: $0.aspectRatio,
                    qualityRejected: $0.qualityRejected,
                    createdAt: $0.createdAt
                )
            }
        } catch {
            logger.error("Breed explore gallery load failed")
            return []
        }
    }

    func saveAccepted(
        galleryKey: String,
        relativeImagePath: String,
        localFilePath: String,
        aspectRatio: Double
    ) async {
        let sid = Self.makeStorageID(galleryKey: galleryKey, relativeImagePath: relativeImagePath)
        let ref = fileStorage.fileReference(for: localFilePath) ?? localFilePath
        do {
            let predicate = #Predicate<StoredBreedExploreGalleryImage> { $0.storageID == sid }
            var descriptor = FetchDescriptor<StoredBreedExploreGalleryImage>(predicate: predicate)
            descriptor.fetchLimit = 1
            if let existing = try context.fetch(descriptor).first {
                if let oldRef = existing.localFilePath, oldRef != ref {
                    fileStorage.removeFile(at: fileStorage.filePath(for: oldRef) ?? oldRef)
                }
                existing.localFilePath = ref
                existing.aspectRatio = aspectRatio
                existing.qualityRejected = false
            } else {
                context.insert(
                    StoredBreedExploreGalleryImage(
                        storageID: sid,
                        galleryKey: galleryKey,
                        relativeImagePath: relativeImagePath,
                        localFilePath: ref,
                        aspectRatio: aspectRatio,
                        qualityRejected: false,
                        createdAt: Date()
                    )
                )
            }
            try context.save()
            removeOrphanedFiles()
        } catch {
            fileStorage.removeFile(at: localFilePath)
            logger.error("Breed explore gallery save accepted failed")
        }
    }

    func markQualityRejected(galleryKey: String, relativeImagePath: String) async {
        let sid = Self.makeStorageID(galleryKey: galleryKey, relativeImagePath: relativeImagePath)
        do {
            let predicate = #Predicate<StoredBreedExploreGalleryImage> { $0.storageID == sid }
            var descriptor = FetchDescriptor<StoredBreedExploreGalleryImage>(predicate: predicate)
            descriptor.fetchLimit = 1
            if let existing = try context.fetch(descriptor).first {
                if let ref = existing.localFilePath {
                    fileStorage.removeFile(at: fileStorage.filePath(for: ref) ?? ref)
                }
                existing.localFilePath = nil
                existing.qualityRejected = true
            } else {
                context.insert(
                    StoredBreedExploreGalleryImage(
                        storageID: sid,
                        galleryKey: galleryKey,
                        relativeImagePath: relativeImagePath,
                        localFilePath: nil,
                        aspectRatio: 1.0,
                        qualityRejected: true,
                        createdAt: Date()
                    )
                )
            }
            try context.save()
            removeOrphanedFiles()
        } catch {
            logger.error("Breed explore gallery mark rejected failed")
        }
    }

    private func isValid(_ item: StoredBreedExploreGalleryImage) -> Bool {
        if item.qualityRejected { return true }
        guard let ref = item.localFilePath else { return false }
        return fileStorage.fileExists(at: fileStorage.filePath(for: ref))
    }

    private func delete(_ item: StoredBreedExploreGalleryImage) {
        if let ref = item.localFilePath {
            fileStorage.removeFile(at: fileStorage.filePath(for: ref) ?? ref)
        }
        context.delete(item)
    }

    private func removeOrphanedFiles() {
        guard let stored = try? context.fetch(FetchDescriptor<StoredBreedExploreGalleryImage>()) else { return }
        let referencedPaths = Set(
            stored.compactMap { fileStorage.filePath(for: $0.localFilePath) }.filter { !$0.isEmpty }
        )
        fileStorage.removeOrphanedFiles(referencedPaths: referencedPaths)
    }
}

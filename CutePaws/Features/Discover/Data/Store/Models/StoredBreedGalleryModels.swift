import Foundation
import SwiftData

@Model
final class StoredBreedGalleryItem {
    @Attribute(.unique) var remoteURLString: String
    var breedName: String
    var subBreedName: String
    var sourceRaw: String
    var createdAt: Date
    var localFilePath: String?
    var aspectRatio: Double

    init(
        remoteURLString: String,
        breedName: String,
        subBreedName: String,
        sourceRaw: String,
        createdAt: Date,
        localFilePath: String?,
        aspectRatio: Double
    ) {
        self.remoteURLString = remoteURLString
        self.breedName = breedName
        self.subBreedName = subBreedName
        self.sourceRaw = sourceRaw
        self.createdAt = createdAt
        self.localFilePath = localFilePath
        self.aspectRatio = aspectRatio
    }
}

@Model
final class StoredBreedThumbnailItem {
    @Attribute(.unique) var catalogKey: String
    var breedName: String
    var subBreedName: String
    var thumbnailImageData: Data
    var aspectRatio: Double
    var remoteURLString: String
    var sourceRaw: String
    var updatedAt: Date

    init(
        catalogKey: String,
        breedName: String,
        subBreedName: String,
        thumbnailImageData: Data,
        aspectRatio: Double,
        remoteURLString: String,
        sourceRaw: String,
        updatedAt: Date
    ) {
        self.catalogKey = catalogKey
        self.breedName = breedName
        self.subBreedName = subBreedName
        self.thumbnailImageData = thumbnailImageData
        self.aspectRatio = aspectRatio
        self.remoteURLString = remoteURLString
        self.sourceRaw = sourceRaw
        self.updatedAt = updatedAt
    }
}

@Model
final class StoredBreedExploreMetadata {
    @Attribute(.unique) var singletonKey: String
    var catalogPayload: Data?
    var thumbnailBootstrapCompleted: Bool

    init(singletonKey: String, catalogPayload: Data?, thumbnailBootstrapCompleted: Bool) {
        self.singletonKey = singletonKey
        self.catalogPayload = catalogPayload
        self.thumbnailBootstrapCompleted = thumbnailBootstrapCompleted
    }
}

@Model
final class StoredBreedExploreGalleryImage {
    @Attribute(.unique) var storageID: String
    var galleryKey: String
    var relativeImagePath: String
    var localFilePath: String?
    var aspectRatio: Double
    var qualityRejected: Bool
    var createdAt: Date

    init(
        storageID: String,
        galleryKey: String,
        relativeImagePath: String,
        localFilePath: String?,
        aspectRatio: Double,
        qualityRejected: Bool,
        createdAt: Date
    ) {
        self.storageID = storageID
        self.galleryKey = galleryKey
        self.relativeImagePath = relativeImagePath
        self.localFilePath = localFilePath
        self.aspectRatio = aspectRatio
        self.qualityRejected = qualityRejected
        self.createdAt = createdAt
    }
}

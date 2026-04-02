import Foundation

@MainActor
@Observable
final class BreedImagesViewModel {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var items: [MediaItem] = []

    let sectionTitle: String

    private let breedName: String
    private let breedGalleryRepository: BreedGalleryRepository

    init(breedName: String, breedGalleryRepository: BreedGalleryRepository) {
        self.breedName = breedName
        self.breedGalleryRepository = breedGalleryRepository
        sectionTitle = BreedExploreDisplayName.gallerySectionTitle(breedName: breedName)
    }

    func load() async {
        phase = .loading
        do {
            items = try await breedGalleryRepository.loadBreedExploreGalleryMediaItems(breedName: breedName)
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

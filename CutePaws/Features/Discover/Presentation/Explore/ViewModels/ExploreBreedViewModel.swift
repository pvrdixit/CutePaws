import Foundation

@MainActor
@Observable
final class ExploreBreedViewModel {
    private(set) var snapshot: ExploreBreedListSnapshot?
    private(set) var hasCompletedInitialLoad = false

    private let breedGalleryRepository: BreedGalleryRepository

    init(breedGalleryRepository: BreedGalleryRepository) {
        self.breedGalleryRepository = breedGalleryRepository
    }

    func refresh() async {
        snapshot = await breedGalleryRepository.loadExploreBreedListSnapshot()
        hasCompletedInitialLoad = true
    }
}

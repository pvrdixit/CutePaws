import Combine
import Foundation

@MainActor
final class ExploreBreedViewModel: ObservableObject {
    @Published private(set) var snapshot: ExploreBreedListSnapshot?
    @Published private(set) var hasCompletedInitialLoad = false

    private let breedGalleryRepository: BreedGalleryRepository

    init(breedGalleryRepository: BreedGalleryRepository) {
        self.breedGalleryRepository = breedGalleryRepository
    }

    func refresh() async {
        snapshot = await breedGalleryRepository.loadExploreBreedListSnapshot()
        hasCompletedInitialLoad = true
    }
}

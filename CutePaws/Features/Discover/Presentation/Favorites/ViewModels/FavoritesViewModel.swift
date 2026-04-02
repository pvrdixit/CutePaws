import Foundation

@MainActor
@Observable
final class FavoritesViewModel: Identifiable {
    let id = UUID()

    private(set) var items: [DetailMediaItem] = []
    var selectedIndex = 0
    var showRemoveFavoriteAlert = false

    private let favoriteRepository: FavoriteRepository

    init(favoriteRepository: FavoriteRepository) {
        self.favoriteRepository = favoriteRepository
    }

    var currentItem: DetailMediaItem? {
        guard items.indices.contains(selectedIndex) else { return nil }
        return items[selectedIndex]
    }

    var currentDisplayName: String {
        currentItem?.displayName ?? ""
    }

    var shouldShowDisplayName: Bool {
        !currentDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var positionText: String {
        guard !items.isEmpty else { return "" }
        return "\(selectedIndex + 1) of \(items.count)"
    }

    func load() {
        Task { [weak self] in
            guard let self else { return }
            let favorites = await favoriteRepository.loadFavorites()
            let mapped = favorites.map {
                DetailMediaItem(
                    id: $0.id,
                    sourceID: $0.sourceID,
                    displayName: $0.displayName,
                    mediaType: $0.mediaType,
                    imagePath: $0.localFilePath
                )
            }
            guard !Task.isCancelled else { return }
            items = mapped
            selectedIndex = min(selectedIndex, max(0, mapped.count - 1))
        }
    }

    func requestRemoveCurrentFavorite() {
        guard currentItem != nil else { return }
        showRemoveFavoriteAlert = true
    }

    func confirmRemoveCurrentFavorite() {
        guard let current = currentItem else { return }
        Task { [weak self] in
            guard let self else { return }
            await favoriteRepository.removeFavorite(sourceID: current.sourceID)
            guard !Task.isCancelled else { return }
            removeCurrentItemFromList()
        }
    }

    private func removeCurrentItemFromList() {
        guard items.indices.contains(selectedIndex) else { return }
        items.remove(at: selectedIndex)
        if items.isEmpty {
            selectedIndex = 0
            return
        }
        selectedIndex = min(selectedIndex, items.count - 1)
    }
}


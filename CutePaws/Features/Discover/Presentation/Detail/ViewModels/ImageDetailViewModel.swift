import Combine
import Foundation

@MainActor
final class ImageDetailViewModel: ObservableObject, Identifiable {
    let id = UUID()
    private let favoriteRepository: FavoriteRepository
    private let flow: ImageDetailFlow

    /// Top bar label (matches `SectionHeadingView` titles on Discover / breed gallery).
    let sectionChromeTitle: String

    @Published private(set) var items: [DetailMediaItem]
    @Published var selectedIndex: Int
    @Published var isCurrentFavorite = false

    init(
        items: [DetailMediaItem],
        selectedItemID: String,
        flow: ImageDetailFlow,
        favoriteRepository: FavoriteRepository,
        sectionChromeTitle: String? = nil
    ) {
        self.items = items
        self.flow = flow
        self.favoriteRepository = favoriteRepository
        self.sectionChromeTitle = sectionChromeTitle ?? Self.defaultSectionChromeTitle(for: flow)
        selectedIndex = items.firstIndex { $0.id == selectedItemID } ?? 0
    }

    private static func defaultSectionChromeTitle(for flow: ImageDetailFlow) -> String {
        switch flow {
        case .dailyPicks: return "Daily Picks"
        case .spotlight: return "Spotlight"
        case .miniMoments: return "Mini Moments"
        case .breedExplore: return "Explore"
        }
    }

    var currentItem: DetailMediaItem? {
        guard items.indices.contains(selectedIndex) else { return nil }
        return items[selectedIndex]
    }

    var currentDisplayName: String {
        currentItem?.displayName ?? "Dog"
    }

    var shouldShowDisplayName: Bool {
        flow == .dailyPicks || flow == .breedExplore
    }

    var positionText: String {
        guard !items.isEmpty else { return "" }
        return "\(selectedIndex + 1) of \(items.count)"
    }

    func refreshFavoriteState() {
        guard let sourceID = currentItem?.sourceID else {
            isCurrentFavorite = false
            return
        }
        Task { [weak self] in
            guard let self else { return }
            let isFavorite = await favoriteRepository.isFavorite(sourceID: sourceID)
            guard !Task.isCancelled else { return }
            self.isCurrentFavorite = isFavorite
        }
    }

    func toggleFavorite() {
        guard currentItem != nil else { return }
        if isCurrentFavorite {
            removeCurrentFromFavorites()
            return
        }
        addCurrentToFavorites()
    }

    private func addCurrentToFavorites() {
        guard let currentItem else { return }
        Task { [weak self] in
            guard let self else { return }
            await favoriteRepository.addFavorite(
                sourceID: currentItem.sourceID,
                displayName: currentItem.displayName,
                mediaType: currentItem.mediaType,
                sourceFilePath: currentItem.imagePath
            )
            guard !Task.isCancelled else { return }
            self.isCurrentFavorite = true
        }
    }

    private func removeCurrentFromFavorites() {
        guard let currentItem else { return }
        Task { [weak self] in
            guard let self else { return }
            await favoriteRepository.removeFavorite(sourceID: currentItem.sourceID)
            guard !Task.isCancelled else { return }
            isCurrentFavorite = false
        }
    }
}

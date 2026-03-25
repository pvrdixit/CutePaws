import Combine
import Foundation

@MainActor
final class ImageDetailViewModel: ObservableObject, Identifiable {
    let id = UUID()
    let items: [MediaItem]

    @Published var selectedIndex: Int

    init(items: [MediaItem], selectedItemID: String) {
        self.items = items
        selectedIndex = items.firstIndex { $0.id == selectedItemID } ?? 0
    }

    var currentItem: MediaItem? {
        guard items.indices.contains(selectedIndex) else { return nil }
        return items[selectedIndex]
    }

    var currentBreedName: String {
        guard let currentItem else { return "Dog" }
        return Self.breedName(from: currentItem.remoteURL)
    }

    var positionText: String {
        guard !items.isEmpty else { return "" }
        return "\(selectedIndex + 1) of \(items.count)"
    }

    private static func breedName(from url: URL) -> String {
        guard
            let breedsIndex = url.pathComponents.firstIndex(of: "breeds"),
            url.pathComponents.indices.contains(breedsIndex + 1)
        else {
            return "Dog"
        }

        return url.pathComponents[breedsIndex + 1]
            .split(separator: "-")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

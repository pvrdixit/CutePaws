import Foundation

/// Human-readable breed labels for explore flows and Daily Picks (dog.ceo URLs).
enum BreedExploreDisplayName {
    static func hyphenatedSlug(_ raw: String) -> String {
        raw.split(separator: "-").map(\.capitalized).joined(separator: " ")
    }

    /// Section title when browsing a breed gallery (flat breed slug from `/api/breeds/list`).
    static func gallerySectionTitle(breedName: String) -> String {
        hyphenatedSlug(breedName)
    }

    /// First path segment after `breeds/` in a dog.ceo image URL, title-cased (e.g. `terrier-yorkshire` → "Terrier Yorkshire").
    static func dailyPickLabel(fromDogCeoImageURL url: URL) -> String {
        guard
            let breedsIndex = url.pathComponents.firstIndex(of: "breeds"),
            url.pathComponents.indices.contains(breedsIndex + 1)
        else {
            return "Dog"
        }
        return hyphenatedSlug(String(url.pathComponents[breedsIndex + 1]))
    }
}

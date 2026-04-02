import Foundation

/// Filtered explore list: flat breeds from `/api/breeds/list` that have a stored thumbnail.
struct ExploreBreedListSnapshot: Equatable, Sendable {
    let rows: [ExploreBreedRow]
}

struct ExploreBreedRow: Identifiable, Equatable, Sendable {
    let breedName: String
    let listThumbnail: BreedThumbnailItem

    var id: String { breedName }
}

extension ExploreBreedListSnapshot {
    static func build(breedNames: [String], thumbnails: [BreedThumbnailItem]) -> ExploreBreedListSnapshot {
        let thumbByKey = Dictionary(uniqueKeysWithValues: thumbnails.map { ($0.id, $0) })
        var rows: [ExploreBreedRow] = []

        for breedName in breedNames {
            let key = BreedThumbnailItem.catalogKey(breedName: breedName, subBreedName: "")
            guard let thumb = thumbByKey[key] else { continue }
            rows.append(
                ExploreBreedRow(
                    breedName: breedName,
                    listThumbnail: thumb
                )
            )
        }

        return ExploreBreedListSnapshot(rows: rows)
    }
}

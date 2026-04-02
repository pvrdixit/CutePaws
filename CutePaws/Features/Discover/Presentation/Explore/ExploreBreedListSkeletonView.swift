import SwiftUI

/// Shown while explore breed snapshot is loading; uses `BreedThumbnailPlaceholder` from Assets.
struct ExploreBreedListSkeletonView: View {
    private let rowCount = 10

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(0..<rowCount, id: \.self) { _ in
                    ExploreBreedSkeletonRow()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollContentBackground(.hidden)
    }
}

private struct ExploreBreedSkeletonRow: View {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            BreedExploreThumbnailView(imageData: nil)

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .frame(width: 160, height: 18)
            }

            Spacer(minLength: 8)
            ExploreDisclosureChevron()
        }
        .padding(.vertical, 4)
    }
}

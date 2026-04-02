import SwiftUI

struct ExploreBreedView: View {
    @State private var viewModel: ExploreBreedViewModel
    @State private var searchText = ""
    let onSelectBreed: (String) -> Void

    init(
        breedGalleryRepository: BreedGalleryRepository,
        onSelectBreed: @escaping (String) -> Void
    ) {
        self.onSelectBreed = onSelectBreed
        _viewModel = State(wrappedValue: ExploreBreedViewModel(breedGalleryRepository: breedGalleryRepository))
    }

    var body: some View {
        Group {
            if !viewModel.hasCompletedInitialLoad {
                ExploreBreedListSkeletonView()
            } else if viewModel.snapshot == nil {
                ExploreThumbnailsSyncingStateView {
                    Task { await viewModel.refresh() }
                }
            } else if let snapshot = viewModel.snapshot {
                if snapshot.rows.isEmpty {
                    EmptyStateView(
                        title: "No breeds yet",
                        message: "Thumbnails are still preparing. Pull back later from Discover.",
                        buttonTitle: nil,
                        action: nil
                    )
                } else if filteredRows.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(filteredRows) { row in
                                Button {
                                    onSelectBreed(row.breedName)
                                } label: {
                                    ExploreBreedRowContent(row: row)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 12)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Color.appBackground
                .ignoresSafeArea()
        }
        .navigationTitle("Explore breeds")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            exploreSearchBar
        }
        .task {
            await viewModel.refresh()
        }
    }

    private var filteredRows: [ExploreBreedRow] {
        guard let snapshot = viewModel.snapshot else { return [] }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return snapshot.rows }
        return snapshot.rows.filter { row in
            let slug = BreedExploreDisplayName.hyphenatedSlug(row.breedName).lowercased()
            let name = row.breedName.lowercased()
            return slug.contains(q) || name.contains(q)
        }
    }

    private var exploreSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(uiColor: .label).opacity(0.55))
            TextField("Search breeds", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, DiscoverSectionDetailChromeLayout.bottomChromeHorizontalPadding)
        .padding(.top, DiscoverSectionDetailChromeLayout.bottomChromeTopPadding)
        .padding(.bottom, DiscoverSectionDetailChromeLayout.bottomChromeBottomPadding)
    }
}

private struct ExploreBreedRowContent: View {
    let row: ExploreBreedRow

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            BreedExploreThumbnailView(imageData: row.listThumbnail.thumbnailImageData)
            VStack(alignment: .leading, spacing: 4) {
                Text(BreedExploreDisplayName.hyphenatedSlug(row.breedName))
                    .font(.custom("Didot Bold", size: 15))
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 8)
            ExploreDisclosureChevron()
        }
        .padding(.vertical, 4)
    }
}

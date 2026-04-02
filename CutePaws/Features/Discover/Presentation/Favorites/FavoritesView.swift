import SwiftUI

struct FavoritesView: View {
    @Bindable var viewModel: FavoritesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isCurrentImageZoomed = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.appBackground
                .ignoresSafeArea()

            if viewModel.items.isEmpty {
                EmptyStateView(
                    title: "No favorites yet",
                    message: "Tap the heart on any image to add it here.",
                    buttonTitle: nil,
                    action: nil
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .simultaneousGesture(DetailPullDownDismiss.gesture(onDismiss: dismiss.callAsFunction))
            } else {
                DetailImagePagerView(
                    items: viewModel.items,
                    selectedIndex: $viewModel.selectedIndex,
                    currentItemID: viewModel.currentItem?.id,
                    isCurrentImageZoomed: $isCurrentImageZoomed,
                    onDismiss: dismiss.callAsFunction
                )
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ImageDetailHeaderView(
                        displayName: viewModel.currentDisplayName,
                        positionText: viewModel.positionText,
                        showDisplayName: viewModel.shouldShowDisplayName,
                        isFavorite: true,
                        onFavoriteTap: viewModel.requestRemoveCurrentFavorite,
                        onCloseTap: {},
                        showsCloseButton: false
                    )
                    .padding(.horizontal, DiscoverSectionDetailChromeLayout.bottomChromeHorizontalPadding)
                    .padding(.top, DiscoverSectionDetailChromeLayout.bottomChromeTopPadding)
                    .padding(.bottom, DiscoverSectionDetailChromeLayout.bottomChromeBottomPadding)
                }
            }

            favoritesTopChrome
        }
        .onAppear {
            viewModel.load()
        }
        .onChange(of: viewModel.selectedIndex) { _, _ in
            isCurrentImageZoomed = false
        }
        .alert("Remove Favorite?", isPresented: $viewModel.showRemoveFavoriteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                viewModel.confirmRemoveCurrentFavorite()
            }
        } message: {
            Text("This may delete the media permanently.")
        }
        .statusBarHidden()
    }

    /// Title + close for empty and non-empty favorites (detail name / heart sit at the bottom when items exist).
    private var favoritesTopChrome: some View {
        HStack(alignment: .center, spacing: 12) {
            SectionHeadingView(title: "Favorites")
            Spacer()
            DetailChromeCloseButton(action: dismiss.callAsFunction)
        }
        .padding(.horizontal, DiscoverSectionDetailChromeLayout.topBarHorizontalPadding)
        .padding(.top, DiscoverSectionDetailChromeLayout.topBarTopPadding)
    }
}

private struct FavoritesPreviewRepository: FavoriteRepository {
    func loadFavorites() async -> [FavoriteItem] { [] }
    func isFavorite(sourceID: String) async -> Bool { false }
    func addFavorite(sourceID: String, displayName: String, mediaType: FavoriteMediaType, sourceFilePath: String?) async {}
    func removeFavorite(sourceID: String) async {}
}

#Preview {
    @Previewable @State var viewModel = FavoritesViewModel(favoriteRepository: FavoritesPreviewRepository())
    FavoritesView(viewModel: viewModel)
}

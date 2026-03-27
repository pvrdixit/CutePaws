import SwiftUI

struct FavoritesView: View {
    @ObservedObject var viewModel: FavoritesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isCurrentImageZoomed = false

    var body: some View {
        ZStack(alignment: .top) {
            AppBackgroundView().ignoresSafeArea()

            if viewModel.items.isEmpty {
                EmptyStateView(
                    title: "No favorites yet",
                    message: "Tap the heart on any image to add it here.",
                    buttonTitle: nil,
                    action: nil
                )
            } else {
                DetailImagePagerView(
                    items: viewModel.items,
                    selectedIndex: $viewModel.selectedIndex,
                    currentItemID: viewModel.currentItem?.id,
                    isCurrentImageZoomed: $isCurrentImageZoomed,
                    onDismiss: dismiss.callAsFunction
                )
            }

            ImageDetailHeaderView(
                displayName: viewModel.currentDisplayName,
                positionText: viewModel.positionText,
                showDisplayName: viewModel.shouldShowDisplayName,
                isFavorite: true,
                onFavoriteTap: viewModel.requestRemoveCurrentFavorite,
                onCloseTap: dismiss.callAsFunction
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
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
}

private struct FavoritesPreviewRepository: FavoriteRepository {
    func loadFavorites() async -> [FavoriteItem] { [] }
    func isFavorite(sourceID: String) async -> Bool { false }
    func addFavorite(sourceID: String, displayName: String, mediaType: FavoriteMediaType, sourceFilePath: String?) async {}
    func removeFavorite(sourceID: String) async {}
}

#Preview {
    FavoritesView(viewModel: FavoritesViewModel(favoriteRepository: FavoritesPreviewRepository()))
}


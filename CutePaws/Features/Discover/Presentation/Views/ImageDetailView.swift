import SwiftUI
struct ImageDetailView: View {
    @ObservedObject var viewModel: ImageDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isCurrentImageZoomed = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.appBackground.ignoresSafeArea()

            DetailImagePagerView(
                items: viewModel.items,
                selectedIndex: $viewModel.selectedIndex,
                currentItemID: viewModel.currentItem?.id,
                isCurrentImageZoomed: $isCurrentImageZoomed,
                onDismiss: dismiss.callAsFunction
            )

            ImageDetailHeaderView(
                displayName: viewModel.currentDisplayName,
                positionText: viewModel.positionText,
                showDisplayName: viewModel.shouldShowDisplayName,
                isFavorite: viewModel.isCurrentFavorite,
                onFavoriteTap: viewModel.toggleFavorite,
                onCloseTap: dismiss.callAsFunction
            )
                .padding(.horizontal, 16)
                .padding(.top, 12)
        }
        .onAppear {
            viewModel.refreshFavoriteState()
        }
        .onChange(of: viewModel.selectedIndex) { _, _ in
            isCurrentImageZoomed = false
            viewModel.refreshFavoriteState()
        }
        .statusBarHidden()
    }
}

#Preview {
    let dependencies = AppDependencies()
    let items = PreviewData.mediaItems.map {
        DetailMediaItem(
            id: $0.id,
            sourceID: $0.id,
            displayName: "Dog",
            mediaType: .photo,
            imagePath: $0.localFilePath
        )
    }
    return ImageDetailView(
        viewModel: ImageDetailViewModel(
            items: items,
            selectedItemID: items[0].id,
            flow: .dailyPicks,
            favoriteRepository: dependencies.favoriteRepository
        )
    ).preferredColorScheme(.dark)
}

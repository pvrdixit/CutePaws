import SwiftUI

struct ImageDetailView: View {
    @ObservedObject var viewModel: ImageDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isCurrentImageZoomed = false

    init(viewModel: ImageDetailViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppBackgroundView().ignoresSafeArea()

            DetailImagePagerView(
                items: viewModel.items,
                selectedIndex: $viewModel.selectedIndex,
                currentItemID: viewModel.currentItem?.id,
                isCurrentImageZoomed: $isCurrentImageZoomed,
                onDismiss: { dismiss() }
            )
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ImageDetailHeaderView(
                    displayName: viewModel.currentDisplayName,
                    positionText: viewModel.positionText,
                    showDisplayName: viewModel.shouldShowDisplayName,
                    isFavorite: viewModel.isCurrentFavorite,
                    onFavoriteTap: viewModel.toggleFavorite,
                    onCloseTap: {},
                    showsCloseButton: false
                )
                .padding(.horizontal, DiscoverSectionDetailChromeLayout.bottomChromeHorizontalPadding)
                .padding(.top, DiscoverSectionDetailChromeLayout.bottomChromeTopPadding)
                .padding(.bottom, DiscoverSectionDetailChromeLayout.bottomChromeBottomPadding)
            }

            sectionTopChrome
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

    private var sectionTopChrome: some View {
        HStack(alignment: .center, spacing: 12) {
            SectionHeadingView(title: viewModel.sectionChromeTitle)
            Spacer()
            DetailChromeCloseButton(action: dismiss.callAsFunction)
        }
        .padding(.horizontal, DiscoverSectionDetailChromeLayout.topBarHorizontalPadding)
        .padding(.top, DiscoverSectionDetailChromeLayout.topBarTopPadding)
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

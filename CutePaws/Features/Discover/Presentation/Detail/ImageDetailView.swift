import SwiftUI

struct ImageDetailView: View {
    @Bindable var viewModel: ImageDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isCurrentImageZoomed = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.appBackground
                .ignoresSafeArea()

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
    @Previewable @State var viewModel = ImageDetailViewModel(
        items: [
            DetailMediaItem(id: "1", sourceID: "1", displayName: "Golden", mediaType: .photo, imagePath: nil),
            DetailMediaItem(id: "2", sourceID: "2", displayName: "Husky", mediaType: .photo, imagePath: nil),
        ],
        selectedItemID: "1",
        flow: .dailyPicks,
        favoriteRepository: AppDependencies().favoriteRepository
    )
    ImageDetailView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}

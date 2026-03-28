import SwiftUI

struct DiscoverView: View {
    @StateObject var viewModel: DiscoverViewModel

    private enum Layout {
        static let horizontalPadding: CGFloat = 12
        static let sectionHeaderBottomSpacing: CGFloat = 15.0
        static let spacingAfterSection: CGFloat = 30
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                content(proxy: proxy)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(item: $viewModel.imageDetailViewModel, onDismiss: viewModel.dismissImageDetail) { imageDetailViewModel in
            ImageDetailView(viewModel: imageDetailViewModel)
        }
        .fullScreenCover(item: $viewModel.favoritesViewModel, onDismiss: viewModel.dismissFavoritesView) { favoritesViewModel in
            FavoritesView(viewModel: favoritesViewModel)
        }
    }

    @ViewBuilder
    private func content(proxy: GeometryProxy) -> some View {
        switch viewModel.state {
        case .loading:
            LoadingView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    AppBackgroundView().ignoresSafeArea()
                }

        case .error(let message):
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    titleView

                    VStack(spacing: 12) {
                        Text(message)
                        Button("Try Again") { viewModel.retry() }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, max(proxy.safeAreaInsets.top + 8, 20))
                .padding(.bottom, max(proxy.safeAreaInsets.bottom + 20, 34))
                .frame(width: proxy.size.width, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                AppBackgroundView().ignoresSafeArea()
            }

        case .loaded:
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Title
                    titleView
                        .padding(.horizontal, Layout.horizontalPadding)
                        .padding(.bottom, Layout.spacingAfterSection)

                    // Spotlight section
                    section {
                        DiscoverSectionView(title: "Spotlight")
                            .padding(.horizontal, Layout.horizontalPadding)
                    } content: {
                        SpotlightView(
                            imagePath: viewModel.spotlightImagePath,
                            aspectRatio: viewModel.spotlightAspectRatio,
                            onTap: viewModel.showSpotlightImageDetail
                        )
                            .padding(.horizontal, Layout.horizontalPadding)
                    }

                    DiscoverMiniMomentsSectionView(
                        items: viewModel.miniMoments,
                        onSelectItem: { _ in }
                    )
                    .padding(.horizontal, Layout.horizontalPadding)
                    .padding(.bottom, Layout.spacingAfterSection)

                    DiscoverGifsSectionView(
                        items: viewModel.gifs,
                        onSelectItem: { _ in }
                    )
                    .padding(.horizontal, Layout.horizontalPadding)
                    .padding(.bottom, Layout.spacingAfterSection)

                    // Daily Picks section
                    section {
                        DiscoverSectionView(title: "Daily Picks")
                            .padding(.horizontal, Layout.horizontalPadding)
                    } content: {
                        MasonryTwoColumnGrid(
                            items: viewModel.items,
                            availableWidth: proxy.size.width - 2 * Layout.horizontalPadding,
                            spacing: 12.0,
                            onSelect: viewModel.showImageDetail
                        )
                        .padding(.horizontal, Layout.horizontalPadding)
                    }
                }
                .padding(.top, proxy.safeAreaInsets.top)
                .padding(.bottom, proxy.safeAreaInsets.bottom)
                .frame(width: proxy.size.width, alignment: .topLeading)
            }
            .background {
                AppBackgroundView().ignoresSafeArea()
            }
        }
    }

    private var titleView: some View {
        HStack(spacing: 12) {
            DiscoverTitleView(title: "Discover")
            Spacer()
            exploreButton
            favoritesButton
        }
    }

    private var exploreButton: some View {
        Button(action: {}) {
            Label("Explore breeds", systemImage: "sparkles")
                .foregroundStyle(.accent)
                .lineLimit(1)
                .font(.custom("Didot Bold", size: 13))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var favoritesButton: some View {
        Button(action: viewModel.showFavorites) {
            Image(systemName: "heart.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.accent)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section builder
    @ViewBuilder
    private func section<Header: View, Content: View>(@ViewBuilder header: () -> Header, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Layout.sectionHeaderBottomSpacing) {
            header()
            content()
        }
        .padding(.bottom, Layout.spacingAfterSection)
    }
}

#Preview("DiscoverView Light") {
    let dependencies = AppDependencies()
    return DiscoverView(viewModel: dependencies.makeDiscoverViewModel())
        .preferredColorScheme(.light)
}

#Preview("DiscoverView Dark") {
    let dependencies = AppDependencies()
    return DiscoverView(viewModel: dependencies.makeDiscoverViewModel())
        .preferredColorScheme(.dark)
}

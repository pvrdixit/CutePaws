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
    }

    @ViewBuilder
    private func content(proxy: GeometryProxy) -> some View {
        switch viewModel.state {
        case .loading:
            LoadingView()

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
            .background(Color(uiColor: .systemBackground))

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
                            onTap: viewModel.retry
                        )
                            .padding(.horizontal, Layout.horizontalPadding)
                    }

                    // Daily Picks section
                    section {
                        DiscoverSectionView(title: "Daily Picks")
                            .padding(.horizontal, Layout.horizontalPadding)
                    } content: {
                        MasonryTwoColumnGrid(
                            items: viewModel.items,
                            availableWidth: proxy.size.width - 2 * Layout.horizontalPadding,
                            spacing: 8,
                            onSelect: viewModel.showImageDetail
                        )
                        .padding(.horizontal, Layout.horizontalPadding)
                    }
                }
                .padding(.top, proxy.safeAreaInsets.top)
                .padding(.bottom, proxy.safeAreaInsets.bottom)
                .frame(width: proxy.size.width, alignment: .topLeading)
            }
            .background(Color(uiColor: .systemBackground))
        }
    }

    private var titleView: some View {
        DiscoverTitleView(title: "Discover")
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

#Preview {
    let dependencies = AppDependencies()
    return DiscoverView(viewModel: dependencies.makeDiscoverViewModel())
}

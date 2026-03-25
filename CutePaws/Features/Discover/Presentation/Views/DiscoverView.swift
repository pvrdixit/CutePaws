import SwiftUI

struct DiscoverView: View {
    @StateObject var viewModel: DiscoverViewModel

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
                VStack(alignment: .leading, spacing: 24) {
                    titleView
                    DiscoverSectionView(title: "Daily Picks")
                    MasonryTwoColumnGrid(
                        items: viewModel.items,
                        availableWidth: proxy.size.width - 40,
                        onSelect: viewModel.showImageDetail
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, max(proxy.safeAreaInsets.top + 8, 20))
                .padding(.bottom, max(proxy.safeAreaInsets.bottom + 20, 34))
                .frame(width: proxy.size.width, alignment: .topLeading)
            }
            .background(Color(uiColor: .systemBackground))
        }
    }

    private var titleView: some View {
        DiscoverTitleView(title: "Discover")
    }
}

#Preview {
    let dependencies = AppDependencies()
    return DiscoverView(viewModel: dependencies.makeDiscoverViewModel())
}

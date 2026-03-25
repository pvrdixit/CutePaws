import SwiftUI

struct DiscoverView: View {
    @StateObject var viewModel: DiscoverViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DiscoverTitleView(title: "Discover")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                content
            }
            .toolbar(.hidden, for: .navigationBar)
                .task { viewModel.start() }
        }
        .fullScreenCover(item: $viewModel.imageDetailViewModel, onDismiss: viewModel.dismissImageDetail) { imageDetailViewModel in
            ImageDetailView(viewModel: imageDetailViewModel)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            LoadingView()

        case .error(let message):
            VStack(spacing: 12) {
                Text(message)
                Button("Try Again") { viewModel.retry() }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded:
            MasonryTwoColumnGrid(items: viewModel.items, onSelect: viewModel.showImageDetail)
        }
    }
}

#Preview {
    let dependencies = AppDependencies()
    return DiscoverView(viewModel: dependencies.makeDiscoverViewModel())
}

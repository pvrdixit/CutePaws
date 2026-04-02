import SwiftUI

struct BreedImagesView: View {
    private enum Layout {
        static let horizontalPadding: CGFloat = 12
        static let gridSpacing: CGFloat = 12
    }

    let breedName: String
    let onRequestImageDetail: (ImageDetailViewModel) -> Void

    @State private var viewModel: BreedImagesViewModel

    private let favoriteRepository: FavoriteRepository

    init(
        breedName: String,
        breedGalleryRepository: BreedGalleryRepository,
        favoriteRepository: FavoriteRepository,
        onRequestImageDetail: @escaping (ImageDetailViewModel) -> Void
    ) {
        self.breedName = breedName
        self.favoriteRepository = favoriteRepository
        self.onRequestImageDetail = onRequestImageDetail
        _viewModel = State(
            wrappedValue: BreedImagesViewModel(
                breedName: breedName,
                breedGalleryRepository: breedGalleryRepository
            )
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                Group {
                    switch viewModel.phase {
                    case .idle, .loading:
                        LoadingView(caption: nil)
                    case .failed(let message):
                        EmptyStateView(
                            title: "Couldn’t load images",
                            message: message,
                            buttonTitle: "Try again",
                            action: { Task { await viewModel.load() } }
                        )
                    case .loaded:
                        if viewModel.items.isEmpty {
                            EmptyStateView(
                                title: "Sorry, we couldn't find images for this breed",
                                message: "Please try again or choose another breed.",
                                buttonTitle: "Try again",
                                action: { Task { await viewModel.load() } }
                            )
                        } else {
                            ScrollView(showsIndicators: false) {
                                MasonryTwoColumnGrid(
                                    items: viewModel.items,
                                    availableWidth: proxy.size.width - 2 * Layout.horizontalPadding,
                                    spacing: Layout.gridSpacing,
                                    onSelect: showImageDetail(for:)
                                )
                                .padding(.horizontal, Layout.horizontalPadding)
                                .padding(.top, 8)
                                .padding(.bottom, proxy.safeAreaInsets.bottom + 16)
                                .frame(width: proxy.size.width, alignment: .topLeading)
                            }
                            .scrollContentBackground(.hidden)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(viewModel.sectionTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }

    private func showImageDetail(for item: MediaItem) {
        let detailItems = viewModel.items.map {
            DetailMediaItem(
                id: $0.id,
                sourceID: $0.id,
                displayName: BreedExploreDisplayName.dailyPickLabel(fromDogCeoImageURL: $0.remoteURL),
                mediaType: .photo,
                imagePath: $0.localFilePath
            )
        }
        let vm = ImageDetailViewModel(
            items: detailItems,
            selectedItemID: item.id,
            flow: .breedExplore,
            favoriteRepository: favoriteRepository,
            sectionChromeTitle: viewModel.sectionTitle
        )
        onRequestImageDetail(vm)
    }
}

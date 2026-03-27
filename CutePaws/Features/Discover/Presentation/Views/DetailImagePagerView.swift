import SwiftUI

struct DetailImagePagerView: View {
    let items: [DetailMediaItem]
    @Binding var selectedIndex: Int
    let currentItemID: String?
    @Binding var isCurrentImageZoomed: Bool
    let onDismiss: () -> Void

    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                imagePage(for: item)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    guard !isCurrentImageZoomed else { return }
                    guard value.translation.height > 120 else { return }
                    guard abs(value.translation.height) > abs(value.translation.width) else { return }
                    onDismiss()
                }
        )
    }

    @ViewBuilder
    private func imagePage(for item: DetailMediaItem) -> some View {
        if hasImage(at: item.imagePath) {
            ZoomableImageView(
                imagePath: item.imagePath,
                imageID: item.id,
                isSelected: currentItemID == item.id
            ) { isZoomed in
                if currentItemID == item.id {
                    isCurrentImageZoomed = isZoomed
                }
            }
            .ignoresSafeArea()
        } else {
            ContentUnavailableView("Image unavailable", systemImage: "photo")
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
    }

    private func hasImage(at path: String?) -> Bool {
        guard let path else { return false }
        return ImageCache.shared.image(forFilePath: path) != nil
    }
}

private struct DetailImagePagerPreviewHost: View {
    @State private var selectedIndex = 0
    @State private var isZoomed = false

    private let items = PreviewData.mediaItems.prefix(3).map {
        DetailMediaItem(
            id: $0.id,
            sourceID: $0.id,
            displayName: "Dog",
            mediaType: .photo,
            imagePath: $0.localFilePath
        )
    }

    var body: some View {
        DetailImagePagerView(
            items: items,
            selectedIndex: $selectedIndex,
            currentItemID: items.indices.contains(selectedIndex) ? items[selectedIndex].id : nil,
            isCurrentImageZoomed: $isZoomed,
            onDismiss: {}
        )
        .background(Color.appBackground)
    }
}

#Preview {
    DetailImagePagerPreviewHost()
}


import AVFoundation
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
                mediaPage(for: item)
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
    private func mediaPage(for item: DetailMediaItem) -> some View {
        switch item.mediaType {
        case .photo:
            photoPage(for: item)
        case .video:
            videoPage(for: item)
        }
    }

    @ViewBuilder
    private func photoPage(for item: DetailMediaItem) -> some View {
        if hasCachedImage(at: item.imagePath) {
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

    @ViewBuilder
    private func videoPage(for item: DetailMediaItem) -> some View {
        if let path = item.imagePath, FileManager.default.fileExists(atPath: path) {
            DetailAspectFittedVideoPage(url: URL(fileURLWithPath: path))
                .ignoresSafeArea()
        } else {
            ContentUnavailableView("Video unavailable", systemImage: "video.slash")
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
    }

    private func hasCachedImage(at path: String?) -> Bool {
        guard let path else { return false }
        return ImageCache.shared.image(forFilePath: path) != nil
    }
}

// MARK: - Aspect fit (same idea as photo aspect fit)

private struct DetailAspectFittedVideoPage: View {
    let url: URL

    @State private var aspectRatio: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            let size = Self.aspectFitSize(
                container: proxy.size,
                mediaAspectWidthOverHeight: max(aspectRatio, 0.01)
            )
            LoopingVideoView(url: url, isMuted: false, videoGravity: .resizeAspect)
                .frame(width: size.width, height: size.height)
                .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.5)
        }
        .task(id: url.path) {
            if let r = await MediaAspectRatioReader.videoAspectRatio(fileURL: url) {
                aspectRatio = r
            }
        }
    }

    private static func aspectFitSize(container: CGSize, mediaAspectWidthOverHeight r: CGFloat) -> CGSize {
        guard r > 0, container.width > 0, container.height > 0 else {
            return CGSize(width: container.width, height: container.height)
        }
        var width = container.width
        var height = width / r
        if height > container.height {
            height = container.height
            width = height * r
        }
        return CGSize(width: width, height: height)
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

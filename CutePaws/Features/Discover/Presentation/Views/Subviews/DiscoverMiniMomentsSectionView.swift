import SwiftUI

struct DiscoverMiniMomentsSectionView: View {
    let items: [MiniMomentItem]
    let onSelectItem: (MiniMomentItem) -> Void

    var body: some View {
        DiscoverHorizontalMediaRailSection(title: "Mini Moments", items: items) { item in
            MiniMomentCard(item: item) {
                onSelectItem(item)
            }
        }
    }
}

private struct MiniMomentCard: View {
    let item: MiniMomentItem
    let onTap: () -> Void

    @State private var aspectRatio: CGFloat = MediaAspectRatioReader.videoRailFallbackAspectRatio

    var body: some View {
        DiscoverMediaRailLocalFileSlot(localPath: item.localFilePath) { url in
            LoopingVideoView(url: url, isMuted: true)
        }
        .discoverMediaRailCardChrome(width: DiscoverMediaRailLayout.clampedCardWidth(aspectRatio: aspectRatio), onTap: onTap)
        .task(id: item.localFilePath) {
            aspectRatio = await MediaAspectRatioReader.videoDisplayAspectRatio(localPath: item.localFilePath)
        }
    }
}

#Preview {
    DiscoverMiniMomentsSectionView(items: [], onSelectItem: { _ in })
        .padding()
}

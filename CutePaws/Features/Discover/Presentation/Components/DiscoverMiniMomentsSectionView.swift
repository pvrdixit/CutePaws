import SwiftUI

struct DiscoverMiniMomentsSectionView: View {
    let items: [MiniMomentItem]
    let showsPreviewCaption: Bool
    let onSelectItem: (MiniMomentItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                SectionHeadingView(title: "Mini Moments")
                if showsPreviewCaption {
                    Text("Preview clip — your first download will appear here too.")
                        .font(.custom("Didot", size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            if items.isEmpty {
                Text("No videos available yet. They’ll show up here after the first one finishes downloading.")
                    .font(.custom("Didot", size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(items) { item in
                            MiniMomentCard(item: item) {
                                onSelectItem(item)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct MiniMomentCard: View {
    let item: MiniMomentItem
    let onTap: () -> Void

    @State private var aspectRatio: CGFloat = VideoAspectRatioReader.railFallbackAspectRatio

    var body: some View {
        DiscoverMediaRailLocalFileSlot(localPath: item.localFilePath) { url in
            LoopingVideoView(url: url, isMuted: true)
        }
        .discoverMediaRailCardChrome(width: DiscoverMediaRailLayout.clampedCardWidth(aspectRatio: aspectRatio), onTap: onTap)
        .task(id: item.localFilePath) {
            aspectRatio = await VideoAspectRatioReader.videoDisplayAspectRatio(localPath: item.localFilePath)
        }
    }
}

#Preview {
    DiscoverMiniMomentsSectionView(items: [], showsPreviewCaption: false, onSelectItem: { _ in })
        .padding()
}

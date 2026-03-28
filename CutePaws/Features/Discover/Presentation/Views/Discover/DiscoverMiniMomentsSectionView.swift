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

    @State private var aspectRatio: CGFloat = 0.96

    var body: some View {
        MiniMomentSurface(item: item)
            .frame(width: DiscoverMediaRailLayout.clampedCardWidth(aspectRatio: aspectRatio), height: DiscoverMediaRailLayout.cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .onTapGesture(perform: onTap)
            .task(id: item.localFilePath) {
                guard let path = item.localFilePath else {
                    aspectRatio = 0.96
                    return
                }
                let url = URL(fileURLWithPath: path)
                if let ratio = await MediaAspectRatioReader.videoAspectRatio(fileURL: url) {
                    aspectRatio = ratio
                } else {
                    aspectRatio = 0.96
                }
            }
    }
}

private struct MiniMomentSurface: View {
    let item: MiniMomentItem

    var body: some View {
        Group {
            if let path = item.localFilePath {
                LoopingVideoView(url: URL(fileURLWithPath: path), isMuted: true)
            } else {
                Rectangle().fill(Color.secondary.opacity(0.2))
            }
        }
    }
}

#Preview {
    DiscoverMiniMomentsSectionView(items: [], onSelectItem: { _ in })
        .padding()
}

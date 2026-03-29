import SwiftUI

enum DiscoverMediaRailLayout {
    static let cardHeight: CGFloat = 200

    static func clampedCardWidth(aspectRatio: CGFloat) -> CGFloat {
        max(140, min(420, cardHeight * aspectRatio))
    }
}

struct DiscoverHorizontalMediaRailSection<Item: Identifiable, Content: View>: View {
    let title: String
    let items: [Item]
    @ViewBuilder let card: (Item) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DiscoverSectionView(title: title)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(items) { item in
                        card(item)
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Shared rail chrome

extension View {
    func discoverMediaRailCardChrome(width: CGFloat, onTap: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return frame(width: width, height: DiscoverMediaRailLayout.cardHeight)
            .clipShape(shape)
            .contentShape(shape)
            .onTapGesture(perform: onTap)
    }
}

/// Placeholder when `localPath` is nil; otherwise builds content with a file URL.
struct DiscoverMediaRailLocalFileSlot<Content: View>: View {
    let localPath: String?
    @ViewBuilder let content: (URL) -> Content

    var body: some View {
        if let localPath {
            content(URL(fileURLWithPath: localPath))
        } else {
            Rectangle().fill(Color.secondary.opacity(0.2))
        }
    }
}

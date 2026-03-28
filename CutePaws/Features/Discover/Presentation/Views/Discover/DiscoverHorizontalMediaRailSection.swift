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

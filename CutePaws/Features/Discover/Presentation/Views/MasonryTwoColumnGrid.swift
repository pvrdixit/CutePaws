import SwiftUI
import UIKit

struct MasonryTwoColumnGrid: View {
    let items: [MediaItem]
    let availableWidth: CGFloat
    let onSelect: (MediaItem) -> Void

    /// Same spacing for left edge, right edge, middle (between columns), and vertical (between cells).
    let spacing: CGFloat

    private let cornerRadius: CGFloat = 14

    init(
        items: [MediaItem],
        availableWidth: CGFloat,
        spacing: CGFloat = 12,
        onSelect: @escaping (MediaItem) -> Void
    ) {
        self.items = items
        self.availableWidth = availableWidth
        self.spacing = spacing
        self.onSelect = onSelect
    }

    var body: some View {
        // Two columns: column width is computed from (left + middle + right + two columns).
        let usableWidth = max(0, availableWidth - (spacing * 3))
        let columnWidth = max(1, usableWidth / 2)
        let columns = split(items: items, columnWidth: columnWidth)

        HStack(alignment: .top, spacing: spacing) {
            VStack(spacing: spacing) {
                ForEach(columns.left) { item in
                    MasonryCell(
                        item: item,
                        width: columnWidth,
                        cornerRadius: cornerRadius,
                        onSelect: onSelect
                    )
                }
            }

            VStack(spacing: spacing) {
                ForEach(columns.right) { item in
                    MasonryCell(
                        item: item,
                        width: columnWidth,
                        cornerRadius: cornerRadius,
                        onSelect: onSelect
                    )
                }
            }
        }
        .padding(.leading, spacing)
        .padding(.trailing, spacing)
        .frame(width: availableWidth, alignment: .topLeading)
    }

    private func split(items: [MediaItem], columnWidth: CGFloat) -> MasonryColumns {
        var left: [MediaItem] = []
        var right: [MediaItem] = []

        var leftHeight: CGFloat = 0
        var rightHeight: CGFloat = 0

        for item in items {
            let ratio = max(0.01, CGFloat(item.aspectRatio))
            let estimatedHeight = columnWidth / ratio

            if leftHeight < rightHeight {
                left.append(item)
                leftHeight += estimatedHeight + spacing
            } else {
                right.append(item)
                rightHeight += estimatedHeight + spacing
            }
        }

        return MasonryColumns(
            left: left,
            right: right
        )
    }
}

private struct MasonryColumns {
    let left: [MediaItem]
    let right: [MediaItem]
}

private struct MasonryCell: View {
    let item: MediaItem
    let width: CGFloat
    let cornerRadius: CGFloat
    let onSelect: (MediaItem) -> Void

    var body: some View {
        let ratio = max(0.01, CGFloat(item.aspectRatio))
        let height = width / ratio

        Button {
            onSelect(item)
        } label: {
            Group {
                if let image = loadImage(from: item.localFilePath) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: width, height: height)
                } else {
                    Rectangle()
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .overlay(Text("Failed").font(.caption))
                }
            }
            .frame(width: width, height: height)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func loadImage(from path: String?) -> UIImage? {
        ImageCache.shared.image(forFilePath: path)
    }
}

#Preview("Masonry Grid") {
    GeometryReader { geometry in
        MasonryTwoColumnGrid(
            items: PreviewData.mediaItems,
            availableWidth: geometry.size.width,
            spacing: 12,
            onSelect: { _ in }
        )
        .background(Color(uiColor: .systemBackground))
    }
}

#Preview("Masonry Cell") {
    GeometryReader { geometry in
        MasonryCell(
            item: PreviewData.mediaItems[0],
            width: geometry.size.width,
            cornerRadius: 14,
            onSelect: { _ in }
        )
        .background(Color(uiColor: .systemBackground))
    }
   
}

import SwiftUI
import UIKit

struct MasonryTwoColumnGrid: View {
    let items: [MediaItem]
    let availableWidth: CGFloat
    let onSelect: (MediaItem) -> Void

    private let gutter: CGFloat = 12
    private let cornerRadius: CGFloat = 14

    var body: some View {
        let columnWidth = max(1, (availableWidth - gutter) / 2)
        let columns = split(items: items, columnWidth: columnWidth)

        HStack(alignment: .top, spacing: gutter) {
            VStack(spacing: gutter) {
                ForEach(columns.left) { item in
                    MasonryCell(
                        item: item,
                        width: columnWidth,
                        cornerRadius: cornerRadius,
                        onSelect: onSelect
                    )
                }
            }

            VStack(spacing: gutter) {
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
        .frame(maxWidth: .infinity, alignment: .top)
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
                leftHeight += estimatedHeight + gutter
            } else {
                right.append(item)
                rightHeight += estimatedHeight + gutter
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
        guard let path else { return nil }
        return UIImage(contentsOfFile: path)
    }
}

#Preview("Masonry Grid") {
    GeometryReader { geometry in
        MasonryTwoColumnGrid(
            items: PreviewData.mediaItems,
            availableWidth: geometry.size.width,
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

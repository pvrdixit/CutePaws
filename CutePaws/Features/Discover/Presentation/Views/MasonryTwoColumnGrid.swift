import SwiftUI
import UIKit

struct MasonryTwoColumnGrid: View {
    let items: [MediaItem]
    let onSelect: (MediaItem) -> Void

    private let gutter: CGFloat = 12
    private let cornerRadius: CGFloat = 14

    var body: some View {
        GeometryReader { geometry in
            let columnWidth = (geometry.size.width - gutter * 3) / 2
            let columns = split(items: items, columnWidth: columnWidth)

            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    HStack(alignment: .top, spacing: gutter) {
                        LazyVStack(spacing: gutter) {
                            ForEach(columns.left) { item in
                                MasonryCell(
                                    item: item,
                                    width: columnWidth,
                                    cornerRadius: cornerRadius,
                                    onSelect: onSelect
                                )
                            }
                        }

                        LazyVStack(spacing: gutter) {
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
                    .padding(.horizontal, gutter)
                    .padding(.vertical, gutter)
                }
            }
        }
    }

    private func split(items: [MediaItem], columnWidth: CGFloat) -> (left: [MediaItem], right: [MediaItem]) {
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

        return (left, right)
    }
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
                if let image = UIImage(data: item.imageData) {
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
}

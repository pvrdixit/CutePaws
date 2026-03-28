import SwiftUI
import ImageIO

struct DiscoverGifsSectionView: View {
    let items: [AnimatedGifItem]
    let onSelectItem: (AnimatedGifItem) -> Void

    var body: some View {
        DiscoverHorizontalMediaRailSection(title: "Gif's", items: items) { item in
            GifCard(item: item) {
                onSelectItem(item)
            }
        }
    }
}

private struct GifCard: View {
    let item: AnimatedGifItem
    let onTap: () -> Void

    var body: some View {
        GifSurface(item: item)
            .frame(width: cardWidth, height: DiscoverMediaRailLayout.cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .onTapGesture(perform: onTap)
    }

    private var cardWidth: CGFloat {
        let ratio = GifAspectRatioResolver.aspectRatio(forLocalPath: item.localFilePath)
        return DiscoverMediaRailLayout.clampedCardWidth(aspectRatio: ratio)
    }
}

private struct GifSurface: View {
    let item: AnimatedGifItem

    var body: some View {
        Group {
            if let path = item.localFilePath {
                AnimatedGifView(fileURL: URL(fileURLWithPath: path))
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
            }
        }
    }
}

private enum GifAspectRatioResolver {
    private static var cache: [String: CGFloat] = [:]

    static func aspectRatio(forLocalPath path: String?) -> CGFloat {
        if let path, let cached = cache[path] {
            return cached
        }

        if let path {
            let value = resolve(url: URL(fileURLWithPath: path))
            cache[path] = value
            return value
        }

        return 1.0
    }

    private static func resolve(url: URL) -> CGFloat {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
            let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
            width > 0,
            height > 0
        else {
            return 1.0
        }

        return width / height
    }
}

#Preview {
    DiscoverGifsSectionView(items: [], onSelectItem: { _ in })
        .padding().preferredColorScheme(.dark)
}

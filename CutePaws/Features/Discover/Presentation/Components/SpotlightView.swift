import SwiftUI
import UIKit

struct SpotlightView: View {
    private let defaultImage: String = "Featured"
    /// Full horizontal width (e.g. screen width) — height follows `width ÷ aspectRatio`.
    let availableWidth: CGFloat
    let imagePath: String?
    let aspectRatio: Double?
    let onTap: () -> Void
    private let cornerRadius: CGFloat = 15.0
    private let fallbackAspectRatio: Double = 1.5
    /// Used only when we don’t have a decoded `UIImage` yet (metadata / placeholder).
    private static let metadataAspectRatioRange: ClosedRange<Double> = 0.5...2.0

    init(
        availableWidth: CGFloat,
        imagePath: String? = nil,
        aspectRatio: Double? = nil,
        onTap: @escaping () -> Void
    ) {
        self.availableWidth = availableWidth
        self.imagePath = imagePath
        self.aspectRatio = aspectRatio
        self.onTap = onTap
    }

    var body: some View {
        let w = max(availableWidth, 1)
        let ar = displayWidthOverHeight
        let h = w / ar

        ZStack(alignment: .bottomLeading) {
            if let image = ImageCache.shared.image(forFilePath: imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(defaultImage)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: w, height: h)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onTapGesture { onTap() }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// Width ÷ height — prefer pixels from the loaded spotlight image for an exact frame.
    private var displayWidthOverHeight: CGFloat {
        if let ui = ImageCache.shared.image(forFilePath: imagePath), ui.size.height > 0 {
            return ui.size.width / ui.size.height
        }
        return CGFloat(resolvedMetadataAspectRatio)
    }

    private var resolvedMetadataAspectRatio: Double {
        let raw: Double
        if let aspectRatio, aspectRatio > 0 {
            raw = aspectRatio
        } else if
            let size = UIImage(named: defaultImage)?.size,
            size.height > 0
        {
            raw = Double(size.width / size.height)
        } else {
            raw = fallbackAspectRatio
        }
        return min(Self.metadataAspectRatioRange.upperBound, max(Self.metadataAspectRatioRange.lowerBound, raw))
    }
}

#Preview("Spotlight") {
    VStack(alignment: .leading, spacing: 16) {
        SectionHeadingView(title: "Spotlight")
            .padding(.horizontal, 12)

        SpotlightView(availableWidth: 360, aspectRatio: 1, onTap: {})
            .padding(.horizontal, 12)
    }
    .padding(.vertical, 24)
}

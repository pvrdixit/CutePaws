import SwiftUI
import UIKit

struct SpotlightView: View {
    private let defaultImage: String = "Featured"
    let imagePath: String?
    let aspectRatio: Double?
    let onTap: () -> Void
    private let cornerRadius: CGFloat = 15.0
    private let fallbackAspectRatio: Double = 1.5

    init(
        imagePath: String? = nil,
        aspectRatio: Double? = nil,
        onTap: @escaping () -> Void
    ) {
        self.imagePath = imagePath
        self.aspectRatio = aspectRatio
        self.onTap = onTap
    }

    var body: some View {
        let aspectRatioValue = aspectRatio ?? fallbackAspectRatio

        ZStack(alignment: .bottomLeading) {
            if let image = ImageCache.shared.image(forFilePath: imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(defaultImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(aspectRatioValue, contentMode: .fit)
        .onTapGesture { onTap() }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

#Preview("Spotlight") {
    VStack(alignment: .leading, spacing: 16) {
        DiscoverSectionView(title: "Spotlight")
            .padding(.horizontal, 12)

        SpotlightView(aspectRatio: 1, onTap: {})
            .padding(.horizontal, 12)
    }
    .padding(.vertical, 24)
}


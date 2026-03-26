import SwiftUI

struct SpotlightView: View {
    let imageName: String
    let title: String
    let onTap: () -> Void
    private let cornerRadius: CGFloat = 15.0

    init(
        imageName: String = "Featured",
        title: String = "Featured",
        onTap: @escaping () -> Void
    ) {
        self.imageName = imageName
        self.title = title
        self.onTap = onTap
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipped()
        }
        .frame(maxWidth: .infinity)
        .onTapGesture { onTap() }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

#Preview("Spotlight") {
    VStack(alignment: .leading, spacing: 16) {
        DiscoverSectionView(title: "Spotlight")
            .padding(.horizontal, 12)

        SpotlightView(onTap: {})
            .padding(.horizontal, 12)
    }
    .padding(.vertical, 24)
}


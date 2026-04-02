import SwiftUI

/// Shared metrics for full-screen section media chrome (`FavoritesView`, `ImageDetailView`).
enum DiscoverSectionDetailChromeLayout {
    static let topBarHorizontalPadding: CGFloat = 12
    static let topBarTopPadding: CGFloat = 12
    static let bottomChromeHorizontalPadding: CGFloat = 16
    static let bottomChromeTopPadding: CGFloat = 12
    static let bottomChromeBottomPadding: CGFloat = 8
}

/// Circular material close control shared by `ImageDetailHeaderView` and `FavoritesView` top chrome.
struct DetailChromeCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Color(uiColor: .label))
                .frame(width: 36, height: 36)
                .background(.regularMaterial)
                .clipShape(Circle())
        }
    }
}

struct ImageDetailHeaderView: View {
    let displayName: String
    let positionText: String
    let showDisplayName: Bool
    let isFavorite: Bool
    let onFavoriteTap: () -> Void
    let onCloseTap: () -> Void
    var showsCloseButton: Bool = true

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if showDisplayName {
                    Text(displayName)
                        .font(.subheadline)
                        .foregroundStyle(Color(uiColor: .label))
                }

                Text(positionText)
                    .font(.caption)
                    .foregroundStyle(Color(uiColor: .label).opacity(0.72))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer()

            Button(action: onFavoriteTap) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(isFavorite ? .accent : .primary)
                    .frame(width: 36, height: 36)
                    .background(.regularMaterial)
                    .clipShape(Circle())
            }

            if showsCloseButton {
                DetailChromeCloseButton(action: onCloseTap)
            }
        }
    }
}

#Preview("Header With Name") {
    ImageDetailHeaderView(
        displayName: "Golden Retriever",
        positionText: "3 of 20",
        showDisplayName: true,
        isFavorite: true,
        onFavoriteTap: {},
        onCloseTap: {}
    )
    .padding()
}

#Preview("Header Position Only") {
    ImageDetailHeaderView(
        displayName: "",
        positionText: "5 of 6",
        showDisplayName: false,
        isFavorite: false,
        onFavoriteTap: {},
        onCloseTap: {}
    )
    .padding()
}

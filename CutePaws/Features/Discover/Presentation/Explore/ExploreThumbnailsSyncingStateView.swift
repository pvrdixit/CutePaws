import SwiftUI

struct ExploreThumbnailsSyncingStateView: View {
    let onRetry: () -> Void

    var body: some View {
        EmptyStateView(
            title: "Almost ready",
            message: "Breed thumbnails are still syncing. Try again in a moment.",
            buttonTitle: "Retry",
            action: onRetry
        )
    }
}

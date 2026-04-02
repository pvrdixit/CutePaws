import SwiftUI

/// Generic empty-state component for screens with no content or a recoverable failure.
struct EmptyStateView: View {
    let title: String
    let message: String
    let buttonTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.custom("Didot Bold", size: 20))

            Text(message)
                .font(.custom("Didot", size: 15))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if let buttonTitle, let action {
                Button(buttonTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Empty State") {
    EmptyStateView(
        title: "No favorites yet",
        message: "Tap the heart on any image to add it here.",
        buttonTitle: "Browse Discover",
        action: {}
    )
    .background(Color.appBackground)
}

#Preview("Empty State Without Action") {
    EmptyStateView(
        title: "Nothing here",
        message: "Content will appear once available.",
        buttonTitle: nil,
        action: nil
    )
    .background(Color.appBackground)
}


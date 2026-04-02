import SwiftUI

/// Large hero title (e.g. Discover tab).
struct LargeDisplayTitleView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.custom("Didot", size: 42))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

enum SectionHeadingStyle: Sendable {
    /// Section labels on the main Discover feed (e.g. Daily Picks).
    case largeDisplay
    /// Compact explore / secondary headers (Didot Bold 13).
    case compactBold
}

/// Section and screen headings used across Discover, explore, and rails.
struct SectionHeadingView: View {
    let title: String
    
    init(title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.custom("Didot", size: 21))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        LargeDisplayTitleView(title: "Discover")
        SectionHeadingView(title: "Daily Picks")
    }
    .padding()
}

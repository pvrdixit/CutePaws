import SwiftUI

/// Large hero title (e.g. Discover tab).
struct LargeDisplayTitleView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.custom("Didot", size: 48))
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
    var style: SectionHeadingStyle

    init(title: String, style: SectionHeadingStyle = .largeDisplay) {
        self.title = title
        self.style = style
    }

    var body: some View {
        Text(title)
            .font(font)
    }

    private var font: Font {
        switch style {
        case .largeDisplay:
            .custom("Didot", size: 24)
        case .compactBold:
            .custom("Didot Bold", size: 13)
        }
    }
}

#Preview("Large display title") {
    LargeDisplayTitleView(title: "Discover")
        .preferredColorScheme(.light)
}

#Preview("Section headings") {
    VStack(alignment: .leading, spacing: 16) {
        SectionHeadingView(title: "Daily Picks", style: .largeDisplay)
        SectionHeadingView(title: "Explore breeds", style: .compactBold)
    }
    .padding()
}

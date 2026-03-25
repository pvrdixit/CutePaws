import SwiftUI

struct DiscoverTitleView: View {
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(title)
            .font(.custom("Didot", size: 44))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(colorScheme == .dark ? Color.white : Color(uiColor: .label))
            .shadow(
                color: colorScheme == .dark ? .black.opacity(0.3) : .white.opacity(0.45),
                radius: 8,
                x: 0,
                y: 4
            )
    }
}


struct DiscoverSectionTitleView: View {
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(title)
            .font(.custom("AvenirNext-DemiBold", size: 20))
            .foregroundStyle(
                colorScheme == .dark
                ? Color.white.opacity(0.96)
                : Color(uiColor: .label).opacity(0.96)
            )
    }
}


#Preview("Discover Title Light") {
    DiscoverTitleView(title: "Discover")
        .preferredColorScheme(.light)
}

#Preview("Discover Title Dark") {
    DiscoverTitleView(title: "Discover")
        .preferredColorScheme(.dark)
}

#Preview("Discover Section Light") {
    DiscoverSectionTitleView(title: "Popular Breeds")
        .preferredColorScheme(.light)
}

#Preview("Discover Section Dark") {
    DiscoverSectionTitleView(title: "Popular Breeds")
        .preferredColorScheme(.dark)
}

import SwiftUI

struct DiscoverTitleView: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.custom("Didot", size: 48))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

struct DiscoverSectionView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.custom("Didot", size: 24))
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
    DiscoverSectionView(title: "Fresh Photos")
        .preferredColorScheme(.light)
}

#Preview("Discover Section Dark") {
    DiscoverSectionView(title: "Fresh Photos")
        .preferredColorScheme(.dark)
}

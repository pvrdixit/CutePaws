import Foundation

struct AboutPrivacyItem: Identifiable, Sendable {
    let id: String
    let title: String
    let systemImage: String
}

struct DiscoverAboutViewModel {
    let creditsSectionTitle = "Credits"
    let dogCeoTitle = "Dog.Ceo API"
    let dogCeoSystemImage = "photo.on.rectangle.angled"
    let dogCeoURL = URL(string: "https://dog.ceo/dog-api/")!
    let randomDogTitle = "Random.Dog"
    let randomDogSystemImage = "dog.fill"
    let randomDogURL = URL(string: "https://random.dog/")!

    let aboutSectionTitle = "About"
    let openSourceTitle = "Open Source"
    let openSourceSystemImage = "link"
    let openSourceURL = URL(string: "https://github.com/pvrdixit")!

    let authorName = "Vijay Raj Dixit"
    let authorRole = "iOS Freelance Developer • SwiftUI / UIKit"
    let appDescription =
        "CutePaws is a production-style dog media app: curated daily picks, spotlight and mini moments, breed explore with thumbnails, and favorites — built with SwiftUI, SwiftData, and a small clean-architecture slice (repositories, remote data, local stores)."

    let privacySectionTitle = "Privacy"
    let privacyItems: [AboutPrivacyItem] = [
        AboutPrivacyItem(id: "noAds", title: "No ads", systemImage: "checkmark.seal"),
        AboutPrivacyItem(id: "noDataCollection", title: "No data collection", systemImage: "hand.raised")
    ]
}

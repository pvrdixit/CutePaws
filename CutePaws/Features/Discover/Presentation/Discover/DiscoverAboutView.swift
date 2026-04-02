import SwiftUI

struct DiscoverAboutView: View {
    @Environment(\.dismiss) private var dismiss
    private let about = DiscoverAboutViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section(about.creditsSectionTitle) {
                    Link(destination: about.dogCeoURL) {
                        Label(about.dogCeoTitle, systemImage: about.dogCeoSystemImage)
                    }
                    Link(destination: about.randomDogURL) {
                        Label(about.randomDogTitle, systemImage: about.randomDogSystemImage)
                    }
                }

                Section(about.aboutSectionTitle) {
                    Link(destination: about.openSourceURL) {
                        Label(about.openSourceTitle, systemImage: about.openSourceSystemImage)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(about.authorName)
                            .font(.headline)

                        Text(about.authorRole)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(about.appDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section(about.privacySectionTitle) {
                    ForEach(about.privacyItems) { item in
                        Label(item.title, systemImage: item.systemImage)
                    }
                }
            }
            .navigationTitle("CutePaws")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    DiscoverAboutView()
}

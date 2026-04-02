import SwiftUI

struct AppBackgroundView: View {

    var body: some View {
        LinearGradient(
            colors: [.accent.opacity(0.2), .appBackground],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview("App Background - Light") {
    AppBackgroundView()
        .ignoresSafeArea()
        .preferredColorScheme(.light)
}

#Preview("App Background - Dark") {
    AppBackgroundView()
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
}


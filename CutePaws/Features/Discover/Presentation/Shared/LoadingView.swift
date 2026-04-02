import SwiftUI

struct LoadingView: View {
    /// When `nil`, only the paw animation is shown (e.g. breed gallery loading).
    var caption: String? = "Getting your daily dose of cuteness..."

    @State private var isFilled = false
    @State private var breathe = false

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Image(systemName: "pawprint")
                        .opacity(isFilled ? 0 : 1)

                    Image(systemName: "pawprint.fill")
                        .opacity(isFilled ? 1 : 0)
                }
                .font(.system(size: 48))
                .foregroundStyle(.accent)
                .frame(width: 72, height: 72)
                .scaleEffect(breathe ? 1.02 : 0.98)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: breathe)
                .animation(.easeInOut(duration: 0.9), value: isFilled)

                if let caption, !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: 18))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color(uiColor: .label))
                }
            }
            .padding(.horizontal, 24)
        }
        .task {
            breathe = true

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.0))
                isFilled.toggle()
            }
        }
    }
}

#Preview {
    LoadingView()
        .preferredColorScheme(.dark)
}

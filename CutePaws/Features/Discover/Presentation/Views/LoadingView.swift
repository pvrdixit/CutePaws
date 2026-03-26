import SwiftUI

struct LoadingView: View {
    @State private var isFilled = false
    @State private var breathe = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.12),
                    Color.appBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Image(systemName: "pawprint")
                        .opacity(isFilled ? 0 : 1)

                    Image(systemName: "pawprint.fill")
                        .opacity(isFilled ? 1 : 0)
                }
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
                .frame(width: 72, height: 72)
                .scaleEffect(breathe ? 1.02 : 0.98)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: breathe)
                .animation(.easeInOut(duration: 0.9), value: isFilled)

                Text("Getting your daily dose of cuteness...")
                    .font(.system(size: 18))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(uiColor: .label))
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

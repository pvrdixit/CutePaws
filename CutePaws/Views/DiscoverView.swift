//
//  DiscoverView.swift
//  CutePaws
//
//  Created by Vijay Raj Dixit on 06/03/26.
//

import SwiftUI

struct DiscoverView: View {
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if isLoading {
                LoadingView()
                    .transition(.opacity)
            } else {
                Text("Discover")
            }
        }
        .task {
            await loadDummyData()
        }
    }

    private func loadDummyData() async {
        isLoading = true
        try? await Task.sleep(for: .seconds(12))

        withAnimation(.easeInOut(duration: 0.6)) {
            isLoading = false
        }
    }
}

#Preview {
    DiscoverView()
}

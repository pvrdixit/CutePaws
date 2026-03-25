import SwiftUI

@main
struct CutePawsApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var discoverViewModel: DiscoverViewModel

    @MainActor
    init() {
        let dependencies = AppDependencies()
        _discoverViewModel = StateObject(wrappedValue: dependencies.makeDiscoverViewModel())
    }

    var body: some Scene {
        WindowGroup {
            DiscoverView(viewModel: discoverViewModel)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                discoverViewModel.clearRefreshDateForTesting()
            }
        }
    }
}

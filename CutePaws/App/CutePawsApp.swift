import SwiftUI

@main
struct CutePawsApp: App {
    @StateObject private var discoverViewModel: DiscoverViewModel

    @MainActor
    init() {
        let dependencies = AppDependencies()
        let discoverViewModel = dependencies.makeDiscoverViewModel()

        #if DEBUG
        print("CutePawsApp: init start")
        #endif

        discoverViewModel.start()
        _discoverViewModel = StateObject(wrappedValue: discoverViewModel)

        #if DEBUG
        print("CutePawsApp: init end")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            DiscoverView(viewModel: discoverViewModel)
        }
    }
}

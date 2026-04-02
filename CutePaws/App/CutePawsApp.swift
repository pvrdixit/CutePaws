import SwiftUI

@main
struct CutePawsApp: App {
    @State private var discoverViewModel: DiscoverViewModel

    @MainActor
    init() {
        let dependencies = AppDependencies()
        let vm = dependencies.makeDiscoverViewModel()

        #if DEBUG
        print("CutePawsApp: init start")
        #endif

        vm.start()
        _discoverViewModel = State(initialValue: vm)

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

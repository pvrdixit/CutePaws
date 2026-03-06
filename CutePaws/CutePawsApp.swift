//
//  CutePawsApp.swift
//  CutePaws
//
//  Created by Vijay Raj Dixit on 06/03/26.
//

import SwiftUI

@main
struct CutePawsApp: App {
    private let appDependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            DiscoverView()
        }
    }
}

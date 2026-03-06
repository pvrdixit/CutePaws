//
//  AppDependencies+Environment.swift
//  CutePaws
//
//  Created by Vijay Raj Dixit on 28/02/26.
//

import SwiftUI

private struct AppDependenciesKey: EnvironmentKey {
    static let defaultValue: AppDependencies = AppDependencies()
}

extension EnvironmentValues {
    var appDependencies: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}

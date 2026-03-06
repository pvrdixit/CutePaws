//
//  AppDependencies.swift
//  CutePaws
//
//  Created by Vijay Raj Dixit on 28/02/26.
//

import Foundation

enum AppRuntimeEnvironment {
    case development
    case production

    static var current: AppRuntimeEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
}

enum LoggerServiceFactory {
    static func make(for environment: AppRuntimeEnvironment, subsystem: String = Bundle.main.bundleIdentifier ?? "CutePaws") -> LoggerService {
        switch environment {
        case .development:
            return OSLoggerService(subsystem: subsystem)
        case .production:
            return RemoteLoggerService() /// Just to define scope, not implemented
        }
    }
}

final class AppDependencies {
    /// Always available
    let logger: LoggerService

    /// Shared infrastructure
    lazy var httpUtility = HTTPUtility(timeout: 8.0)

    init(
        environment: AppRuntimeEnvironment = .current,
        logger: LoggerService? = nil
    ) {
        self.logger = logger ?? LoggerServiceFactory.make(for: environment)
    }
}

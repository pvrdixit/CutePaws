//
//  RemoteLoggerService.swift
//  CutePaws
//
//  Created by Vijay Raj Dixit on 26/02/26.
//


public final class RemoteLoggerService: LoggerService {
    public init() {}

    public func log(_ level: LogLevel,
                    _ message: () -> String,
                    category: LogCategory,
                    metadata: [String: String]?,
                    file: String,
                    function: String,
                    line: Int) {
        
        /// Can add any Remote logger like Crashlytics, Sentry or Custom API.
        /// Crashlytics.crashlytics().log("[\(level)] [\(category)] \(message())")
        _ = (level, message(), category, metadata, file, function, line)
    }
}

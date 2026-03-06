//
//  OSLoggerService.swift
//  CutePaws
//
//  Created by Vijay Raj Dixit on 26/02/26.
//

import Foundation
import os

public final class OSLoggerService: LoggerService {
    private let subsystem: String

    public init(subsystem: String) {
        self.subsystem = subsystem
    }

    public func log(_ level: LogLevel,
                    _ message: () -> String,
                    category: LogCategory,
                    metadata: [String: String]?,
                    file: String,
                    function: String,
                    line: Int) {
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        let metadataText = Self.render(metadata)
        let rendered = "\(message())\(metadataText) (\(file):\(line) \(function))"
        logger.log(level: level.osType, "\(rendered, privacy: .public)")
    }

    private static func render(_ metadata: [String: String]?) -> String {
        guard let metadata, !metadata.isEmpty else { return "" }
        let renderedPairs = metadata
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        return " [\(renderedPairs)]"
    }
}

private extension LogLevel {
    var osType: OSLogType {
        switch self {
        case .debug:   return .debug
        case .info:    return .info
        case .warning: return .default
        case .error:   return .error
        }
    }
}

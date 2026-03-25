import Foundation
import os

final class AppLogger {
    private let logger: Logger

    init(subsystem: String) {
        logger = Logger(subsystem: subsystem, category: "app")
    }

    func error(_ message: String, metadata: [String: String]? = nil) {
        let suffix = render(metadata)
        logger.error("\(message)\(suffix, privacy: .public)")
    }

    private func render(_ metadata: [String: String]?) -> String {
        guard let metadata, !metadata.isEmpty else { return "" }

        let pairs = metadata
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")

        return " [\(pairs)]"
    }
}

import Foundation

protocol MediaFileStorage {
    func saveImageData(_ data: Data, suggestedPathExtension: String?) throws -> String
    func removeFile(at path: String)
    func fileExists(at path: String?) -> Bool
    func filePath(for reference: String?) -> String?
    func fileReference(for path: String?) -> String?
    func removeOrphanedFiles(referencedPaths: Set<String>)
}

final class DefaultMediaFileStorage: MediaFileStorage {
    private let fileManager: FileManager
    private let directoryURL: URL

    init(
        fileManager: FileManager = .default,
        directoryName: String = "DiscoverMedia"
    ) {
        self.fileManager = fileManager
        directoryURL = fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CutePaws", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)

        #if DEBUG
        print("\(directoryName) storage folder:", directoryURL.path)
        #endif
    }

    func saveImageData(_ data: Data, suggestedPathExtension: String?) throws -> String {
        try ensureDirectoryExists()

        let fileURL = directoryURL
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(normalizedPathExtension(from: suggestedPathExtension))

        try data.write(to: fileURL, options: .atomic)
        debugLog("saveImageData path=\(fileURL.path) bytes=\(data.count)")
        return fileURL.path
    }

    func removeFile(at path: String) {
        try? fileManager.removeItem(atPath: path)
        debugLog("removeFile path=\(path)")
    }

    func fileExists(at path: String?) -> Bool {
        guard let path, !path.isEmpty else { return false }
        return fileManager.fileExists(atPath: path)
    }

    func filePath(for reference: String?) -> String? {
        guard let reference, !reference.isEmpty else { return nil }

        if reference.hasPrefix(directoryURL.path) {
            return reference
        }

        if reference.contains("/") {
            let fileName = URL(fileURLWithPath: reference).lastPathComponent
            return directoryURL.appendingPathComponent(fileName).path
        }

        return directoryURL.appendingPathComponent(reference).path
    }

    func fileReference(for path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    func removeOrphanedFiles(referencedPaths: Set<String>) {
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        var removedCount = 0
        for fileURL in fileURLs where !referencedPaths.contains(fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
            removedCount += 1
        }

        debugLog("removeOrphanedFiles referenced=\(referencedPaths.count) removed=\(removedCount) totalFiles=\(fileURLs.count)")
    }

    private func ensureDirectoryExists() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
    }

    private func normalizedPathExtension(from suggestedPathExtension: String?) -> String {
        let trimmedExtension = (suggestedPathExtension ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !trimmedExtension.isEmpty else { return "jpg" }
        return trimmedExtension
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("MediaFileStorage:", message)
        #endif
    }
}

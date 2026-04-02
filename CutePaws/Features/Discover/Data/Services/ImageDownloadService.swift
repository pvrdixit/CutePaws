import Foundation

protocol ImageDownloading {
    func downloadImages(from urls: [URL], maxConcurrent: Int) async -> [(url: URL, data: Data)]
    /// Single-image fetch for bounded explore downloads (no multi-attempt retry loop).
    func downloadImage(from url: URL, timeoutInterval: TimeInterval) async -> Data?
}

final class ImageDownloadService: ImageDownloading {
    private let httpUtility: HTTPUtility
    private let mediaRequestTimeout: TimeInterval = 120
    private let maxAttempts = 3

    init(httpUtility: HTTPUtility) {
        self.httpUtility = httpUtility
    }

    func downloadImages(from urls: [URL], maxConcurrent: Int) async -> [(url: URL, data: Data)] {
        let semaphore = AsyncSemaphore(value: max(1, maxConcurrent))
        var results: [(URL, Data)] = []
        results.reserveCapacity(urls.count)

        await withTaskGroup(of: (URL, Data)?.self) { group in
            for url in urls {
                group.addTask { [httpUtility] in
                    await semaphore.acquire()

                    if Task.isCancelled {
                        await semaphore.release()
                        return nil
                    }

                    var lastError: Error?
                    for attempt in 1...self.maxAttempts {
                        var request = URLRequest(url: url)
                        request.timeoutInterval = self.mediaRequestTimeout
                        request.cachePolicy = .reloadIgnoringLocalCacheData

                        do {
                            let data = try await httpUtility.requestData(with: request)
                            await semaphore.release()
                            return (url, data)
                        } catch {
                            lastError = error
                            if attempt < self.maxAttempts {
                                try? await Task.sleep(for: .milliseconds(400 * attempt))
                            }
                        }
                    }

                    #if DEBUG
                    if let lastError {
                        debugPrint(
                            "ImageDownloadService: giving up url=",
                            url.absoluteString,
                            "error=",
                            String(describing: lastError)
                        )
                    }
                    #endif
                    await semaphore.release()
                    return nil
                }
            }

            for await item in group {
                if let item {
                    results.append(item)
                }
            }
        }

        return results
    }

    func downloadImage(from url: URL, timeoutInterval: TimeInterval) async -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeoutInterval
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            return try await httpUtility.requestData(with: request)
        } catch {
            return nil
        }
    }
}

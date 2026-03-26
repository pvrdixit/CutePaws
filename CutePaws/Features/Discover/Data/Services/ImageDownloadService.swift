import Foundation

protocol ImageDownloading {
    func downloadImages(from urls: [URL], maxConcurrent: Int) async -> [(url: URL, data: Data)]
}

final class ImageDownloadService: ImageDownloading {
    private let httpUtility: HTTPUtility

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

                    do {
                        let data = try await httpUtility.requestData(with: URLRequest(url: url))
                        await semaphore.release()
                        return (url, data)
                    } catch {
                        await semaphore.release()
                        return nil
                    }
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
}

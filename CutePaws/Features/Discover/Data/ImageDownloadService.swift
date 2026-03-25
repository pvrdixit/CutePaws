import Foundation

final class ImageDownloadService {
    private let httpUtility: HTTPUtility
    private let minimumImageByteCount = 25 * 1024

    init(httpUtility: HTTPUtility) {
        self.httpUtility = httpUtility
    }

    func downloadImages(from urls: [URL], maxConcurrent: Int) async -> [(url: URL, data: Data)] {
        let semaphore = AsyncSemaphore(value: max(1, maxConcurrent))
        var results: [(URL, Data)] = []
        results.reserveCapacity(urls.count)

        await withTaskGroup(of: (URL, Data)?.self) { group in
            for url in deduplicate(urls) {
                group.addTask { [httpUtility, minimumImageByteCount] in
                    await semaphore.acquire()

                    if Task.isCancelled {
                        await semaphore.release()
                        return nil
                    }

                    do {
                        let data = try await httpUtility.requestData(with: URLRequest(url: url))
                        await semaphore.release()

                        guard data.count >= minimumImageByteCount else { return nil }
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

    private func deduplicate(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { seen.insert($0.absoluteString).inserted }
    }
}

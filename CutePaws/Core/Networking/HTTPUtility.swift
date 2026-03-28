import Foundation

final class HTTPUtility: @unchecked Sendable {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(timeout: TimeInterval) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = max(timeout, 300)
        configuration.waitsForConnectivity = true

        session = URLSession(configuration: configuration)
        decoder = JSONDecoder()
    }

    func request<T: Decodable>(_ type: T.Type, with request: URLRequest) async throws -> T {
        let data = try await requestData(with: request)
        return try decoder.decode(type, from: data)
    }

    func requestData(with request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)

        guard
            let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw URLError(.badServerResponse)
        }

        return data
    }
}

import Foundation

protocol HTTPRequest {
    var urlRequest: URLRequest { get }
}

struct HTTPResponse {
    let data: Data
    let response: HTTPURLResponse
}

protocol HTTPClient {
    func perform(_ request: HTTPRequest) async throws -> HTTPResponse
}

enum HTTPError: Error, Equatable {
    case invalidResponse
    case unacceptableStatus(code: Int)
    case network(URLError)
    case cancelled
    case unknown(Error)
}

extension HTTPError {
    static func map(_ error: Error) -> HTTPError {
        if let httpError = error as? HTTPError {
            return httpError
        }
        if let urlError = error as? URLError {
            if urlError.code == .cancelled {
                return .cancelled
            }
            return .network(urlError)
        }
        return .unknown(error)
    }
}

final class DefaultHTTPClient: NSObject, HTTPClient {
    private let session: URLSession

    init(configuration: URLSessionConfiguration = .default) {
        let config = configuration
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
        super.init()
    }

    func perform(_ request: HTTPRequest) async throws -> HTTPResponse {
        do {
            let (data, response) = try await session.data(for: request.urlRequest)
            guard let http = response as? HTTPURLResponse else {
                throw HTTPError.invalidResponse
            }
            guard (200..<300).contains(http.statusCode) else {
                throw HTTPError.unacceptableStatus(code: http.statusCode)
            }
            return HTTPResponse(data: data, response: http)
        } catch {
            throw HTTPError.map(error)
        }
    }
}

import Foundation
@testable import ITLinkTestTask

final class StubHTTPClient: HTTPClient {
    enum Response {
        case success(data: Data, headers: [String: String] = [:], status: Int = 200)
        case failure(Error)
    }

    private let response: Response

    init(response: Response) {
        self.response = response
    }

    func perform(_ request: HTTPRequest) async throws -> HTTPResponse {
        switch response {
        case let .success(data, headers, status):
            guard let url = request.urlRequest.url,
                  let httpResponse = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers) else {
                throw HTTPError.invalidResponse
            }
            return HTTPResponse(data: data, response: httpResponse)
        case let .failure(error):
            throw error
        }
    }
}

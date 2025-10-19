import XCTest
@testable import ITLinkTestTask

final class LinksFileRemoteDataSourceTests: XCTestCase {
    private let endpoint = URL(string: "https://it-link.ru/test/images.txt")!

    func testParsesRealisticInput() async throws {
        let content = [
            "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSiAiBlU5Oi9hhA1OOExgc-RK0ZSlqoon9aAQ",
            "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQyoGWuJ1GFcGfQ2EWMcCA7piB5AtvdN-USSw",
            "lalala"
        ].joined(separator: "\n")

        let dataSource = makeDataSource(content: content)
        let snapshot = try await dataSource.fetchLinks()

        XCTAssertEqual(snapshot.links.count, 3)
        XCTAssertEqual(snapshot.links[0].contentKind, .image)
        XCTAssertEqual(snapshot.links[1].contentKind, .image)
        XCTAssertEqual(snapshot.links[2].contentKind, .notURL)
    }

    func testDeduplicatesSameUrlsKeepingOrder() async throws {
        let content = "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSiAiBlU5Oi9hhA1OOExgc-RK0ZSlqoon9aAQ\nhttps://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSiAiBlU5Oi9hhA1OOExgc-RK0ZSlqoon9aAQ\nhttps://it-link.ru/logo.png"
        let dataSource = makeDataSource(content: content)
        let snapshot = try await dataSource.fetchLinks()
        XCTAssertEqual(snapshot.links.count, 2)
        XCTAssertEqual(snapshot.links.map { $0.originalText }, [
            "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSiAiBlU5Oi9hhA1OOExgc-RK0ZSlqoon9aAQ",
            "https://it-link.ru/logo.png"
        ])
    }

    func testThrowsWhenEncodingUnsupported() async {
        let bytes: [UInt8] = [0xFF, 0xFF, 0xFF]
        let dataSource = makeDataSource(data: Data(bytes))
        do {
            _ = try await dataSource.fetchLinks()
            XCTFail("Expected failure for invalid encoding")
        } catch {
            XCTAssertTrue(error is NetworkingError)
        }
    }

    private func makeDataSource(content: String) -> DefaultLinksFileRemoteDataSource {
        let response = StubHTTPClient.Response.success(
            data: Data(content.utf8),
            headers: ["Content-Type": "text/plain; charset=utf-8"]
        )
        let client = StubHTTPClient(response: response)
        return DefaultLinksFileRemoteDataSource(endpoint: endpoint, client: client)
    }

    private func makeDataSource(data: Data) -> DefaultLinksFileRemoteDataSource {
        let response = StubHTTPClient.Response.success(
            data: data,
            headers: ["Content-Type": "text/plain"]
        )
        let client = StubHTTPClient(response: response)
        return DefaultLinksFileRemoteDataSource(endpoint: endpoint, client: client)
    }
}

import XCTest
@testable import ITLinkTestTask

final class ImageMetadataProbeTests: XCTestCase {
    func testUsesMimeTypeFromHead() async throws {
        let headers = ["Content-Type": "image/png; charset=utf-8"]
        let client = StubHTTPClient(response: .success(data: Data(), headers: headers))
        let probe = DefaultImageMetadataProbe(client: client)
        let metadata = try await probe.metadata(for: URL(string: "https://it-link.ru/logo.png")!)
        XCTAssertEqual(metadata.format, .png)
        XCTAssertEqual(metadata.mimeType, "image/png")
    }

    func testDetectsWebPWithoutMime() async throws {
        let webpHeader: [UInt8] = [0x52, 0x49, 0x46, 0x46, 0x24, 0x08, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50]
        let data = Data(webpHeader)
        let client = StubHTTPClient(response: .success(data: data, headers: [:]))
        let probe = DefaultImageMetadataProbe(client: client)
        let metadata = try await probe.metadata(for: URL(string: "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSiAiBlU5Oi9hhA1OOExgc-RK0ZSlqoon9aAQ")!)
        XCTAssertEqual(metadata.format, .webp)
    }

    func testUnknownWhenHeaderAndSignatureDoNotMatch() async throws {
        let data = Data([0x00, 0x01, 0x02, 0x03])
        let headers = ["Content-Type": "application/octet-stream"]
        let client = StubHTTPClient(response: .success(data: data, headers: headers))
        let probe = DefaultImageMetadataProbe(client: client)
        let metadata = try await probe.metadata(for: URL(string: "https://example.com/file")!)
        XCTAssertEqual(metadata.format, .unknown)
    }
}

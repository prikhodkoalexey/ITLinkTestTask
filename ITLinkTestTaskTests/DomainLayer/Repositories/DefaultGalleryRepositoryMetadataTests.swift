import XCTest
@testable import ITLinkTestTask

final class DefaultGalleryRepositoryMetadataTests: XCTestCase {
    func testMetadataDelegatesToRemoteService() async throws {
        let harness = GalleryRepositoryTestHarness()
        let imageURL = URL(string: "https://example.com/a.jpg")!
        let metadata = ImageMetadata(format: .jpeg, mimeType: "image/jpeg", originalURL: imageURL)
        await harness.remote.enqueueMetadataResult(.success(metadata), for: imageURL)

        let result = try await harness.repository.metadata(for: imageURL)

        XCTAssertEqual(result.format, .jpeg)
        XCTAssertEqual(result.mimeType, "image/jpeg")
        XCTAssertEqual(result.originalURL, imageURL)
        let metadataRequests = await harness.remote.metadataRequests()
        XCTAssertEqual(metadataRequests, [imageURL])
        let refreshCount = await harness.remote.refreshCallCount()
        XCTAssertEqual(refreshCount, 0)
    }
}

import XCTest
@testable import ITLinkTestTask

final class DefaultGalleryRepositoryImageDataTests: XCTestCase {
    func testImageDataReturnsMemoryCachedValue() async throws {
        let harness = GalleryRepositoryTestHarness()
        let imageURL = URL(string: "https://example.com/a.jpg")!
        let expected = Data([0x01, 0x02])
        harness.memoryCache.setData(expected, for: imageURL, variant: .thumbnail)

        let data = try await harness.repository.imageData(for: imageURL, variant: .thumbnail)

        XCTAssertEqual(data, expected)
        XCTAssertEqual(harness.memoryCache.dataCallCount, 1)
        XCTAssertEqual(harness.memoryCache.storeCallCount, 0)
        let diskDataCalls = await harness.diskCache.dataCallCount()
        XCTAssertEqual(diskDataCalls, 0)
        let diskStoreCalls = await harness.diskCache.storeCallCount()
        XCTAssertEqual(diskStoreCalls, 0)
        XCTAssertEqual(harness.httpClient.requestCount, 0)
    }

    func testImageDataReadsFromDiskAndStoresInMemory() async throws {
        let harness = GalleryRepositoryTestHarness()
        let imageURL = URL(string: "https://example.com/a.jpg")!
        let expected = Data([0x03, 0x04])
        await harness.diskCache.setData(expected, for: imageURL, variant: .thumbnail)

        let data = try await harness.repository.imageData(for: imageURL, variant: .thumbnail)

        XCTAssertEqual(data, expected)
        let diskDataCalls = await harness.diskCache.dataCallCount()
        XCTAssertEqual(diskDataCalls, 1)
        let diskStoreCalls = await harness.diskCache.storeCallCount()
        XCTAssertEqual(diskStoreCalls, 0)
        XCTAssertEqual(harness.memoryCache.storeCallCount, 1)
        XCTAssertEqual(harness.memoryCache.storedData(for: imageURL, variant: .thumbnail), expected)
        XCTAssertEqual(harness.httpClient.requestCount, 0)
    }

    func testImageDataDownloadsWhenMissing() async throws {
        let harness = GalleryRepositoryTestHarness()
        let imageURL = URL(string: "https://example.com/a.jpg")!
        let expected = Data([0x05, 0x06, 0x07])
        let response = makeHTTPResponse(url: imageURL, data: expected)
        harness.httpClient.enqueue(.success(response))

        let data = try await harness.repository.imageData(for: imageURL, variant: .thumbnail)

        XCTAssertEqual(data, expected)
        let diskDataCalls = await harness.diskCache.dataCallCount()
        XCTAssertEqual(diskDataCalls, 1)
        let diskStoreCalls = await harness.diskCache.storeCallCount()
        XCTAssertEqual(diskStoreCalls, 1)
        XCTAssertEqual(harness.memoryCache.storeCallCount, 1)
        XCTAssertEqual(harness.memoryCache.storedData(for: imageURL, variant: .thumbnail), expected)
        XCTAssertEqual(harness.httpClient.requestCount, 1)
        XCTAssertEqual(harness.httpClient.requestedURLs, [imageURL])
    }

    func testImageDataDownloadFailureWrapsError() async throws {
        let harness = GalleryRepositoryTestHarness()
        let imageURL = URL(string: "https://example.com/a.jpg")!
        harness.httpClient.enqueue(.failure(TestStubError.generic))

        do {
            _ = try await harness.repository.imageData(for: imageURL, variant: .thumbnail)
            XCTFail("Expected failure")
        } catch let error as GalleryRepositoryError {
            XCTAssertEqual(error, .imageDataUnavailable(imageURL))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let diskStoreCalls = await harness.diskCache.storeCallCount()
        XCTAssertEqual(diskStoreCalls, 0)
        XCTAssertEqual(harness.memoryCache.storeCallCount, 0)
        XCTAssertEqual(harness.httpClient.requestCount, 1)
    }
}

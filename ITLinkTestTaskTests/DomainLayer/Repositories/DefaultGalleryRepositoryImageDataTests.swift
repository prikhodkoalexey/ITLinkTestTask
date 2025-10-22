import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import ITLinkTestTask

final class DefaultGalleryRepositoryImageDataTests: XCTestCase {
    func testImageDataReturnsMemoryCachedValue() async throws {
        let harness = GalleryRepositoryTestHarness()
        let imageURL = URL(string: "https://example.com/a.jpg")!
        let expected = Data([0x01, 0x02])
        let variant = ImageDataVariant.thumbnail(maxPixelSize: 200)
        harness.memoryCache.setData(expected, for: imageURL, variant: variant)

        let data = try await harness.repository.imageData(for: imageURL, variant: variant)

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
        let variant = ImageDataVariant.thumbnail(maxPixelSize: 160)
        await harness.diskCache.setData(expected, for: imageURL, variant: variant)

        let data = try await harness.repository.imageData(for: imageURL, variant: variant)

        XCTAssertEqual(data, expected)
        let diskDataCalls = await harness.diskCache.dataCallCount()
        XCTAssertEqual(diskDataCalls, 1)
        let diskStoreCalls = await harness.diskCache.storeCallCount()
        XCTAssertEqual(diskStoreCalls, 0)
        XCTAssertEqual(harness.memoryCache.storeCallCount, 1)
        XCTAssertEqual(harness.memoryCache.storedData(for: imageURL, variant: variant), expected)
        XCTAssertEqual(harness.httpClient.requestCount, 0)
    }

    func testImageDataDownloadsWhenMissing() async throws {
        let harness = GalleryRepositoryTestHarness()
        let imageURL = URL(string: "https://example.com/a.jpg")!
        let originalData = try makeTestImageData()
        let response = makeHTTPResponse(url: imageURL, data: originalData)
        harness.httpClient.enqueue(.success(response))
        let variant = ImageDataVariant.thumbnail(maxPixelSize: 180)

        let data = try await harness.repository.imageData(for: imageURL, variant: variant)

        let expectedThumbnail = try generateThumbnailData(from: originalData, maxPixelSize: 180)
        XCTAssertEqual(data, expectedThumbnail)
        let diskDataCalls = await harness.diskCache.dataCallCount()
        XCTAssertEqual(diskDataCalls, 2)
        let diskStoreCalls = await harness.diskCache.storeCallCount()
        XCTAssertEqual(diskStoreCalls, 2)
        XCTAssertEqual(harness.memoryCache.storeCallCount, 2)
        XCTAssertEqual(harness.memoryCache.storedData(for: imageURL, variant: variant), data)
        let storedOriginal = await harness.diskCache.storedData(for: imageURL, variant: .original)
        XCTAssertEqual(storedOriginal, originalData)
        let storedThumbnail = await harness.diskCache.storedData(for: imageURL, variant: variant)
        XCTAssertEqual(storedThumbnail, data)
        XCTAssertEqual(harness.httpClient.requestCount, 1)
        XCTAssertEqual(harness.httpClient.requestedURLs, [imageURL])
    }

    func testImageDataDownloadFailureWrapsError() async throws {
        let harness = GalleryRepositoryTestHarness()
        let imageURL = URL(string: "https://example.com/a.jpg")!
        harness.httpClient.enqueue(.failure(TestStubError.generic))
        let variant = ImageDataVariant.thumbnail(maxPixelSize: 128)

        do {
            _ = try await harness.repository.imageData(for: imageURL, variant: variant)
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

    private func generateThumbnailData(from data: Data, maxPixelSize: Int) throws -> Data {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixelSize)
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            XCTFail("Unable to create thumbnail for test image data")
            return Data()
        }
        let destinationData = NSMutableData()
        let destinationType = CGImageSourceGetType(source) ?? (UTType.png.identifier as CFString)
        guard let destination = CGImageDestinationCreateWithData(destinationData, destinationType, 1, nil) else {
            XCTFail("Unable to encode thumbnail for test image data")
            return Data()
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            XCTFail("Unable to finalize thumbnail for test image data")
            return Data()
        }
        return destinationData as Data
    }

    private func makeTestImageData() throws -> Data {
        var pixel: [UInt8] = [0xFF, 0x22, 0x44, 0xFF]
        guard let provider = CGDataProvider(data: NSData(bytes: &pixel, length: pixel.count)) else {
            throw XCTSkip("Unable to create data provider for test image")
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let image = CGImage(
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            throw XCTSkip("Unable to create CGImage for test data")
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw XCTSkip("Unable to create image destination")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw XCTSkip("Unable to finalize test image data")
        }
        return data as Data
    }
}

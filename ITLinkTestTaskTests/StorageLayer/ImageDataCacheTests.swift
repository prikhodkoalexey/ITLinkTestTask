import Foundation
import XCTest
@testable import ITLinkTestTask

final class ImageDataCacheTests: XCTestCase {
    func testStoresAndReadsData() async throws {
        let env = try makeEnvironment()
        defer { removeTempDirectory(env.temp) }
        let hasher = SHA256FileNameHasher()
        let cache = DefaultImageDataCache(
            store: env.store,
            hasher: hasher,
            fileManager: env.fileManager
        )
        let data = Data([0, 1, 2])
        let variant = ImageDataVariant.thumbnail(maxPixelSize: 150)
        try await cache.store(data, for: URL(string: "https://example.com/a.png")!, variant: variant)
        let loaded = try await cache.data(for: URL(string: "https://example.com/a.png")!, variant: variant)
        XCTAssertEqual(loaded, data)
    }

    func testRemoveDeletesFile() async throws {
        let env = try makeEnvironment()
        defer { removeTempDirectory(env.temp) }
        let hasher = SHA256FileNameHasher()
        let cache = DefaultImageDataCache(
            store: env.store,
            hasher: hasher,
            fileManager: env.fileManager
        )
        let url = URL(string: "https://example.com/a.png")!
        let variant = ImageDataVariant.thumbnail(maxPixelSize: 90)
        try await cache.store(Data([0]), for: url, variant: variant)
        try await cache.remove(for: url, variant: variant)
        let loaded = try await cache.data(for: url, variant: variant)
        XCTAssertNil(loaded)
    }

    func testTrimRemovesOldestFilesWhenLimitExceeded() async throws {
        let env = try makeEnvironment()
        defer { removeTempDirectory(env.temp) }
        let configuration = ImageDataCacheConfiguration(thumbnailLimit: 5, originalLimit: nil)
        let hasher = SHA256FileNameHasher()
        let cache = DefaultImageDataCache(
            store: env.store,
            hasher: hasher,
            fileManager: env.fileManager,
            configuration: configuration
        )
        let firstURL = URL(string: "https://example.com/a.png")!
        let secondURL = URL(string: "https://example.com/b.png")!
        let variant = ImageDataVariant.thumbnail(maxPixelSize: 64)
        try await cache.store(Data([0, 0, 0, 0, 0]), for: firstURL, variant: variant)
        let thumbnailsDirectory = try env.store.directoryURL(for: .thumbnails)
        let firstContents = try env.fileManager.contentsOfDirectory(at: thumbnailsDirectory, includingPropertiesForKeys: nil)
        XCTAssertEqual(firstContents.count, 1)
        let firstFile = firstContents[0]
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 0)],
            ofItemAtPath: firstFile.path
        )
        try await cache.store(Data([1, 1, 1, 1, 1]), for: secondURL, variant: variant)
        let first = try await cache.data(for: firstURL, variant: variant)
        XCTAssertNil(first)
        let second = try await cache.data(for: secondURL, variant: variant)
        XCTAssertNotNil(second)
    }

    private func makeEnvironment() throws -> (temp: URL, store: DiskStore, fileManager: FileManager) {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let fileManager = FileManager()
        let store = try DefaultDiskStore(fileManager: fileManager, baseURL: temp)
        return (temp, store, fileManager)
    }

    private func removeTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

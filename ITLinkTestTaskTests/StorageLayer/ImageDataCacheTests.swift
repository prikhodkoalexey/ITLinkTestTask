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
        try await cache.store(data, for: URL(string: "https://example.com/a.png")!, variant: .thumbnail)
        let loaded = try await cache.data(for: URL(string: "https://example.com/a.png")!, variant: .thumbnail)
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
        try await cache.store(Data([0]), for: url, variant: .thumbnail)
        try await cache.remove(for: url, variant: .thumbnail)
        let loaded = try await cache.data(for: url, variant: .thumbnail)
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
        try await cache.store(Data([0, 0, 0, 0, 0]), for: firstURL, variant: .thumbnail)
        let firstFile = try env.store.fileURL(
            in: .thumbnails,
            fileName: hasher.makeFileName(for: firstURL.absoluteString, fileExtension: firstURL.pathExtension)
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 0)],
            ofItemAtPath: firstFile.path
        )
        try await cache.store(Data([1, 1, 1, 1, 1]), for: secondURL, variant: .thumbnail)
        let first = try await cache.data(for: firstURL, variant: .thumbnail)
        XCTAssertNil(first)
        let second = try await cache.data(for: secondURL, variant: .thumbnail)
        XCTAssertNotNil(second)
    }

    private func makeEnvironment() throws -> (temp: URL, store: DiskStore, fileManager: FileManager) {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        let store = try DefaultDiskStore(fileManager: .default, baseURL: temp)
        return (temp, store, .default)
    }

    private func removeTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

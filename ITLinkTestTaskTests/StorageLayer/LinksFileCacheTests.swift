import Foundation
import XCTest
@testable import ITLinkTestTask

final class LinksFileCacheTests: XCTestCase {
    func testSavesAndLoadsSnapshot() async throws {
        let env = try makeEnvironment()
        defer { removeTempDirectory(env.temp) }
        let cache = DefaultLinksFileCache(store: env.store, fileManager: env.fileManager)
        let snapshot = LinksFileSnapshot(
            sourceURL: URL(string: "https://example.com")!,
            fetchedAt: Date(timeIntervalSince1970: 123),
            links: [
                ImageLinkRecord(lineNumber: 1, originalText: "a", url: URL(string: "https://a"), contentKind: .image)
            ]
        )
        try await cache.saveSnapshot(snapshot)
        let loaded = try await cache.loadSnapshot()
        XCTAssertEqual(loaded, snapshot)
    }

    func testReturnsNilWhenNoSnapshot() async throws {
        let env = try makeEnvironment()
        defer { removeTempDirectory(env.temp) }
        let cache = DefaultLinksFileCache(store: env.store, fileManager: env.fileManager)
        let loaded = try await cache.loadSnapshot()
        XCTAssertNil(loaded)
    }

    func testClearRemovesFile() async throws {
        let env = try makeEnvironment()
        defer { removeTempDirectory(env.temp) }
        let cache = DefaultLinksFileCache(store: env.store, fileManager: env.fileManager)
        let snapshot = LinksFileSnapshot(
            sourceURL: URL(string: "https://example.com")!,
            fetchedAt: Date(),
            links: []
        )
        try await cache.saveSnapshot(snapshot)
        try await cache.clear()
        let loaded = try await cache.loadSnapshot()
        XCTAssertNil(loaded)
    }

    func testThrowsOnCorruptedFile() async throws {
        let env = try makeEnvironment()
        defer { removeTempDirectory(env.temp) }
        let url = try env.store.fileURL(in: .links, fileName: "links.json")
        try "corrupted".data(using: .utf8)?.write(to: url)
        let cache = DefaultLinksFileCache(store: env.store, fileManager: env.fileManager)
        do {
            _ = try await cache.loadSnapshot()
            XCTFail("Expected failure")
        } catch {
            XCTAssertNotNil(error)
        }
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

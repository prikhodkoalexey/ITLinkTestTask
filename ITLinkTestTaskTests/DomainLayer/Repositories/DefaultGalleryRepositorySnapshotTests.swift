import XCTest
@testable import ITLinkTestTask

final class DefaultGalleryRepositorySnapshotTests: XCTestCase {
    func testLoadInitialSnapshotReturnsCachedSnapshot() async throws {
        let harness = GalleryRepositoryTestHarness()
        let cachedSnapshot = makeLinksSnapshot(records: [
            makeRecord(
                line: 1,
                text: "https://example.com/a.jpg",
                url: URL(string: "https://example.com/a.jpg"),
                kind: .image
            ),
            makeRecord(
                line: 2,
                text: "https://example.com",
                url: URL(string: "https://example.com"),
                kind: .nonImageURL
            )
        ])
        await harness.linksCache.setStoredSnapshot(cachedSnapshot)

        let snapshot = try await harness.repository.loadInitialSnapshot()

        XCTAssertEqual(snapshot.items.count, 1)
        XCTAssertEqual(snapshot.items.first?.url, URL(string: "https://example.com/a.jpg"))
        XCTAssertEqual(snapshot.sourceURL, cachedSnapshot.sourceURL)
        XCTAssertEqual(snapshot.fetchedAt, cachedSnapshot.fetchedAt)
        let refreshCount = await harness.remote.refreshCallCount()
        XCTAssertEqual(refreshCount, 0)
        let savedSnapshots = await harness.linksCache.savedSnapshots()
        XCTAssertTrue(savedSnapshots.isEmpty)
        let loadCalls = await harness.linksCache.loadCallCount()
        XCTAssertEqual(loadCalls, 1)
    }

    func testLoadInitialSnapshotFetchesWhenCacheMissing() async throws {
        let harness = GalleryRepositoryTestHarness()
        let remoteSnapshot = makeLinksSnapshot(records: [
            makeRecord(
                line: 1,
                text: "https://example.com/b.jpg",
                url: URL(string: "https://example.com/b.jpg"),
                kind: .image
            )
        ])
        await harness.remote.enqueueRefreshResult(.success(remoteSnapshot))

        let snapshot = try await harness.repository.loadInitialSnapshot()

        XCTAssertEqual(snapshot.items.map(\.url), [URL(string: "https://example.com/b.jpg")])
        let refreshCount = await harness.remote.refreshCallCount()
        XCTAssertEqual(refreshCount, 1)
        let savedSnapshots = await harness.linksCache.savedSnapshots()
        XCTAssertEqual(savedSnapshots, [remoteSnapshot])
        let loadCalls = await harness.linksCache.loadCallCount()
        XCTAssertEqual(loadCalls, 1)
    }

    func testRefreshSnapshotFetchesAndSaves() async throws {
        let harness = GalleryRepositoryTestHarness()
        let remoteSnapshot = makeLinksSnapshot(records: [
            makeRecord(
                line: 1,
                text: "https://example.com/c.jpg",
                url: URL(string: "https://example.com/c.jpg"),
                kind: .image
            )
        ], date: Date(timeIntervalSince1970: 200))
        await harness.remote.enqueueRefreshResult(.success(remoteSnapshot))

        let snapshot = try await harness.repository.refreshSnapshot()

        XCTAssertEqual(snapshot.items.map(\.url), [URL(string: "https://example.com/c.jpg")])
        let refreshCount = await harness.remote.refreshCallCount()
        XCTAssertEqual(refreshCount, 1)
        let savedSnapshots = await harness.linksCache.savedSnapshots()
        XCTAssertEqual(savedSnapshots, [remoteSnapshot])
        let loadCalls = await harness.linksCache.loadCallCount()
        XCTAssertEqual(loadCalls, 0)
    }

    func testRefreshSnapshotReplacesCurrentState() async throws {
        let harness = GalleryRepositoryTestHarness()
        let firstSnapshot = makeLinksSnapshot(records: [
            makeRecord(
                line: 1,
                text: "https://example.com/a.jpg",
                url: URL(string: "https://example.com/a.jpg"),
                kind: .image
            )
        ], date: Date(timeIntervalSince1970: 300))
        let secondSnapshot = makeLinksSnapshot(records: [
            makeRecord(
                line: 1,
                text: "https://example.com/d.jpg",
                url: URL(string: "https://example.com/d.jpg"),
                kind: .image
            )
        ], date: Date(timeIntervalSince1970: 400))
        await harness.remote.enqueueRefreshResult(.success(firstSnapshot))
        await harness.remote.enqueueRefreshResult(.success(secondSnapshot))

        let firstRefresh = try await harness.repository.refreshSnapshot()
        XCTAssertEqual(firstRefresh.items.map(\.url), [URL(string: "https://example.com/a.jpg")])
        let refreshCountAfterFirst = await harness.remote.refreshCallCount()
        XCTAssertEqual(refreshCountAfterFirst, 1)

        let cached = try await harness.repository.loadInitialSnapshot()
        XCTAssertEqual(cached.items.map(\.url), [URL(string: "https://example.com/a.jpg")])
        let refreshCountAfterLoad = await harness.remote.refreshCallCount()
        XCTAssertEqual(refreshCountAfterLoad, 1)

        let secondRefresh = try await harness.repository.refreshSnapshot()
        XCTAssertEqual(secondRefresh.items.map(\.url), [URL(string: "https://example.com/d.jpg")])
        let refreshCountAfterSecond = await harness.remote.refreshCallCount()
        XCTAssertEqual(refreshCountAfterSecond, 2)
    }

    func testRefreshSnapshotFiltersNonImageRecords() async throws {
        let harness = GalleryRepositoryTestHarness()
        let snapshot = makeLinksSnapshot(records: [
            makeRecord(
                line: 1,
                text: "https://example.com/a.jpg",
                url: URL(string: "https://example.com/a.jpg"),
                kind: .image
            ),
            makeRecord(
                line: 2,
                text: "https://example.com",
                url: URL(string: "https://example.com"),
                kind: .nonImageURL
            ),
            makeRecord(
                line: 3,
                text: "plain text",
                url: nil,
                kind: .notURL
            )
        ], date: Date(timeIntervalSince1970: 500))
        await harness.remote.enqueueRefreshResult(.success(snapshot))

        let result = try await harness.repository.refreshSnapshot()

        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items.first?.lineNumber, 1)
        XCTAssertEqual(result.items.first?.originalLine, "https://example.com/a.jpg")
    }
}

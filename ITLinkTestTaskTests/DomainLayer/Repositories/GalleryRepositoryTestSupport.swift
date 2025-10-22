import Foundation
@testable import ITLinkTestTask

struct GalleryRepositoryTestHarness {
    let remote: RecordingRemoteGalleryService
    let linksCache: RecordingLinksFileCache
    let diskCache: RecordingImageDataCache
    let memoryCache: RecordingMemoryImageCache
    let httpClient: RecordingHTTPClient
    let repository: DefaultGalleryRepository

    init() {
        remote = RecordingRemoteGalleryService()
        linksCache = RecordingLinksFileCache()
        diskCache = RecordingImageDataCache()
        memoryCache = RecordingMemoryImageCache()
        httpClient = RecordingHTTPClient()
        repository = DefaultGalleryRepository(
            remoteService: remote,
            linksCache: linksCache,
            diskCache: diskCache,
            memoryCache: memoryCache,
            httpClient: httpClient
        )
    }
}

actor RecordingRemoteGalleryService: RemoteGalleryService {
    private var refreshQueue: [Result<LinksFileSnapshot, Error>] = []
    private var metadataQueues: [URL: [Result<ImageMetadata, Error>]] = [:]
    private var refreshCount = 0
    private var metadataRequestsStorage: [URL] = []

    func enqueueRefreshResult(_ result: Result<LinksFileSnapshot, Error>) {
        refreshQueue.append(result)
    }

    func enqueueMetadataResult(_ result: Result<ImageMetadata, Error>, for url: URL) {
        metadataQueues[url, default: []].append(result)
    }

    func refreshLinks() async throws -> LinksFileSnapshot {
        refreshCount += 1
        guard !refreshQueue.isEmpty else {
            fatalError("Missing refresh result")
        }
        let result = refreshQueue.removeFirst()
        return try result.get()
    }

    func metadata(for url: URL) async throws -> ImageMetadata {
        metadataRequestsStorage.append(url)
        guard var queue = metadataQueues[url], !queue.isEmpty else {
            fatalError("Missing metadata result")
        }
        let result = queue.removeFirst()
        metadataQueues[url] = queue
        return try result.get()
    }

    func refreshCallCount() async -> Int {
        refreshCount
    }

    func metadataRequests() async -> [URL] {
        metadataRequestsStorage
    }
}

actor RecordingLinksFileCache: LinksFileCaching {
    private var stored: LinksFileSnapshot?
    private var saved: [LinksFileSnapshot] = []
    private var loadCount = 0

    func setStoredSnapshot(_ snapshot: LinksFileSnapshot?) {
        stored = snapshot
    }

    func loadSnapshot() async throws -> LinksFileSnapshot? {
        loadCount += 1
        return stored
    }

    func saveSnapshot(_ snapshot: LinksFileSnapshot) async throws {
        saved.append(snapshot)
        stored = snapshot
    }

    func clear() async throws {
        stored = nil
    }

    func savedSnapshots() async -> [LinksFileSnapshot] {
        saved
    }

    func loadCallCount() async -> Int {
        loadCount
    }
}

actor RecordingImageDataCache: ImageDataCaching {
    private struct Key: Hashable {
        let identifier: String
        let namespace: DiskStoreNamespace

        init(url: URL, variant: ImageDataVariant) {
            identifier = variant.cacheKey(for: url)
            namespace = variant.namespace
        }
    }

    private var storage: [Key: Data] = [:]
    private var dataCalls = 0
    private var storeCalls = 0
    private var removeCalls = 0
    private var clearCalls = 0

    func data(for url: URL, variant: ImageDataVariant) async throws -> Data? {
        dataCalls += 1
        return storage[Key(url: url, variant: variant)]
    }

    func store(_ data: Data, for url: URL, variant: ImageDataVariant) async throws {
        storeCalls += 1
        storage[Key(url: url, variant: variant)] = data
    }

    func remove(for url: URL, variant: ImageDataVariant) async throws {
        removeCalls += 1
        storage.removeValue(forKey: Key(url: url, variant: variant))
    }

    func clear(variant: ImageDataVariant) async throws {
        clearCalls += 1
        storage = storage.filter { $0.key.namespace != variant.namespace }
    }

    func setData(_ data: Data?, for url: URL, variant: ImageDataVariant) async {
        let key = Key(url: url, variant: variant)
        if let data {
            storage[key] = data
        } else {
            storage.removeValue(forKey: key)
        }
    }

    func dataCallCount() async -> Int {
        dataCalls
    }

    func storeCallCount() async -> Int {
        storeCalls
    }

    func removeCallCount() async -> Int {
        removeCalls
    }

    func clearCallCount() async -> Int {
        clearCalls
    }

    func storedData(for url: URL, variant: ImageDataVariant) async -> Data? {
        storage[Key(url: url, variant: variant)]
    }
}

final class RecordingMemoryImageCache: MemoryImageCaching, @unchecked Sendable {
    private struct Key: Hashable {
        let rawValue: String

        init(url: URL, variant: ImageDataVariant) {
            rawValue = variant.cacheKey(for: url)
        }
    }

    private var storage: [Key: Data] = [:]
    private(set) var dataCallCount = 0
    private(set) var storeCallCount = 0
    private(set) var removeCallCount = 0
    private(set) var clearCallCount = 0

    func data(for url: URL, variant: ImageDataVariant) -> Data? {
        dataCallCount += 1
        return storage[Key(url: url, variant: variant)]
    }

    func store(_ data: Data, for url: URL, variant: ImageDataVariant) {
        storeCallCount += 1
        storage[Key(url: url, variant: variant)] = data
    }

    func remove(for url: URL, variant: ImageDataVariant) {
        removeCallCount += 1
        storage.removeValue(forKey: Key(url: url, variant: variant))
    }

    func clear() {
        clearCallCount += 1
        storage.removeAll()
    }

    func setData(_ data: Data?, for url: URL, variant: ImageDataVariant) {
        let key = Key(url: url, variant: variant)
        if let data {
            storage[key] = data
        } else {
            storage.removeValue(forKey: key)
        }
    }

    func storedData(for url: URL, variant: ImageDataVariant) -> Data? {
        storage[Key(url: url, variant: variant)]
    }
}

final class RecordingHTTPClient: HTTPClient, @unchecked Sendable {
    private(set) var requests: [URLRequest] = []
    private var results: [Result<HTTPResponse, Error>] = []

    func enqueue(_ result: Result<HTTPResponse, Error>) {
        results.append(result)
    }

    func perform(_ request: HTTPRequest) async throws -> HTTPResponse {
        let urlRequest = request.urlRequest
        requests.append(urlRequest)
        guard !results.isEmpty else {
            fatalError("No queued HTTP results")
        }
        let result = results.removeFirst()
        return try result.get()
    }

    var requestCount: Int {
        requests.count
    }

    var requestedURLs: [URL] {
        requests.compactMap { $0.url }
    }
}

enum TestStubError: Error {
    case generic
}

func makeLinksSnapshot(
    records: [ImageLinkRecord],
    source: URL = URL(string: "https://example.com/source.txt")!,
    date: Date = Date(timeIntervalSince1970: 100)
) -> LinksFileSnapshot {
    LinksFileSnapshot(sourceURL: source, fetchedAt: date, links: records)
}

func makeRecord(
    line: Int,
    text: String,
    url: URL?,
    kind: LinkContentKind
) -> ImageLinkRecord {
    ImageLinkRecord(lineNumber: line, originalText: text, url: url, contentKind: kind)
}

func makeHTTPResponse(
    url: URL,
    data: Data,
    status: Int = 200,
    headers: [String: String] = [:]
) -> HTTPResponse {
    let response = HTTPURLResponse(
        url: url,
        statusCode: status,
        httpVersion: nil,
        headerFields: headers
    )!
    return HTTPResponse(data: data, response: response)
}

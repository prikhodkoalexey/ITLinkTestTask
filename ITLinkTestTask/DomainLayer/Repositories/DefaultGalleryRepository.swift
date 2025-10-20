import Foundation

actor DefaultGalleryRepository: GalleryRepository {
    private let remoteService: RemoteGalleryService
    private let linksCache: any LinksFileCaching
    private let diskCache: any ImageDataCaching
    private let memoryCache: any MemoryImageCaching
    private let httpClient: HTTPClient

    private var currentSnapshot: GallerySnapshot?

    init(
        remoteService: RemoteGalleryService,
        linksCache: any LinksFileCaching,
        diskCache: any ImageDataCaching,
        memoryCache: any MemoryImageCaching,
        httpClient: HTTPClient
    ) {
        self.remoteService = remoteService
        self.linksCache = linksCache
        self.diskCache = diskCache
        self.memoryCache = memoryCache
        self.httpClient = httpClient
    }

    func loadInitialSnapshot() async throws -> GallerySnapshot {
        if let snapshot = currentSnapshot {
            return snapshot
        }
        if let cached = try await linksCache.loadSnapshot() {
            let snapshot = makeSnapshot(from: cached)
            currentSnapshot = snapshot
            return snapshot
        }
        return try await refreshSnapshot()
    }

    func refreshSnapshot() async throws -> GallerySnapshot {
        let linksSnapshot = try await remoteService.refreshLinks()
        try await linksCache.saveSnapshot(linksSnapshot)
        let snapshot = makeSnapshot(from: linksSnapshot)
        currentSnapshot = snapshot
        return snapshot
    }

    func imageData(for url: URL, variant: ImageDataVariant) async throws -> Data {
        if let data = memoryCache.data(for: url, variant: variant) {
            return data
        }
        if let data = try await diskCache.data(for: url, variant: variant) {
            memoryCache.store(data, for: url, variant: variant)
            return data
        }
        let data = try await downloadImage(from: url)
        try await diskCache.store(data, for: url, variant: variant)
        memoryCache.store(data, for: url, variant: variant)
        return data
    }

    func metadata(for url: URL) async throws -> ImageMetadata {
        try await remoteService.metadata(for: url)
    }

    private func makeSnapshot(from snapshot: LinksFileSnapshot) -> GallerySnapshot {
        let items = snapshot.links.compactMap { record -> GalleryImage? in
            guard record.contentKind == .image, let url = record.url else { return nil }
            return GalleryImage(
                url: url,
                originalLine: record.originalText,
                lineNumber: record.lineNumber
            )
        }
        return GallerySnapshot(
            sourceURL: snapshot.sourceURL,
            fetchedAt: snapshot.fetchedAt,
            items: items
        )
    }

    private func downloadImage(from url: URL) async throws -> Data {
        do {
            let response = try await httpClient.perform(ImageDownloadRequest(url: url))
            guard !response.data.isEmpty else {
                throw GalleryRepositoryError.imageDataUnavailable(url)
            }
            return response.data
        } catch is CancellationError {
            throw error
        } catch {
            throw GalleryRepositoryError.imageDataUnavailable(url)
        }
    }
}

private struct ImageDownloadRequest: HTTPRequest {
    let url: URL

    var urlRequest: URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        return request
    }
}

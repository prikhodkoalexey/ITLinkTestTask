import Foundation

protocol RemoteGalleryService {
    func refreshLinks() async throws -> LinksFileSnapshot
    func metadata(for url: URL) async throws -> ImageMetadata
}

final class DefaultRemoteGalleryService: RemoteGalleryService {
    private let linksDataSource: LinksFileRemoteDataSource
    private let metadataProbe: ImageMetadataProbe

    init(linksDataSource: LinksFileRemoteDataSource, metadataProbe: ImageMetadataProbe) {
        self.linksDataSource = linksDataSource
        self.metadataProbe = metadataProbe
    }

    func refreshLinks() async throws -> LinksFileSnapshot {
        try await linksDataSource.fetchLinks()
    }

    func metadata(for url: URL) async throws -> ImageMetadata {
        try await metadataProbe.metadata(for: url)
    }
}

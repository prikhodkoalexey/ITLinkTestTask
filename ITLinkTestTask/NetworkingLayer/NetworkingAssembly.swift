import Foundation

struct NetworkingAssembly {
    let httpClient: HTTPClient
    let linksDataSource: LinksFileRemoteDataSource
    let metadataProbe: ImageMetadataProbe
    let remoteService: RemoteGalleryService

    init(linksEndpoint: URL) {
        let client = DefaultHTTPClient()
        httpClient = client
        linksDataSource = DefaultLinksFileRemoteDataSource(endpoint: linksEndpoint, client: client)
        metadataProbe = DefaultImageMetadataProbe(client: client)
        remoteService = DefaultRemoteGalleryService(linksDataSource: linksDataSource, metadataProbe: metadataProbe)
    }
}

import Foundation

struct GalleryDomainAssembly {
    let repository: any GalleryRepository
    let loadSnapshot: LoadGallerySnapshotUseCase
    let refreshSnapshot: RefreshGallerySnapshotUseCase
    let fetchImageData: FetchGalleryImageDataUseCase
    let fetchMetadata: FetchGalleryMetadataUseCase

    init(repository: any GalleryRepository) {
        self.repository = repository
        loadSnapshot = LoadGallerySnapshotUseCase(repository: repository)
        refreshSnapshot = RefreshGallerySnapshotUseCase(repository: repository)
        fetchImageData = FetchGalleryImageDataUseCase(repository: repository)
        fetchMetadata = FetchGalleryMetadataUseCase(repository: repository)
    }

    init(
        networking: NetworkingAssembly,
        storage: StorageAssembly
    ) {
        let repository = DefaultGalleryRepository(
            remoteService: networking.remoteService,
            linksCache: storage.linksCache,
            diskCache: storage.imageCache,
            memoryCache: storage.memoryCache,
            httpClient: networking.httpClient
        )
        self.init(repository: repository)
    }
}

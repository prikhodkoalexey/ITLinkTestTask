import Foundation

struct LoadGallerySnapshotUseCase {
    private let repository: any GalleryRepository

    init(repository: any GalleryRepository) {
        self.repository = repository
    }

    func execute() async throws -> GallerySnapshot {
        try await repository.loadInitialSnapshot()
    }
}

struct RefreshGallerySnapshotUseCase {
    private let repository: any GalleryRepository

    init(repository: any GalleryRepository) {
        self.repository = repository
    }

    func execute() async throws -> GallerySnapshot {
        try await repository.refreshSnapshot()
    }
}

struct FetchGalleryImageDataUseCase {
    private let repository: any GalleryRepository

    init(repository: any GalleryRepository) {
        self.repository = repository
    }

    func execute(url: URL, variant: ImageDataVariant) async throws -> Data {
        try await repository.imageData(for: url, variant: variant)
    }
}

struct FetchGalleryMetadataUseCase {
    private let repository: any GalleryRepository

    init(repository: any GalleryRepository) {
        self.repository = repository
    }

    func execute(url: URL) async throws -> ImageMetadata {
        try await repository.metadata(for: url)
    }
}

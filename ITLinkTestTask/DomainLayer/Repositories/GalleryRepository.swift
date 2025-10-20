import Foundation

struct GalleryImage: Equatable, Hashable {
    let url: URL
    let originalLine: String
    let lineNumber: Int
}

struct GallerySnapshot: Equatable {
    let sourceURL: URL
    let fetchedAt: Date
    let items: [GalleryImage]

    var isEmpty: Bool { items.isEmpty }
}

enum GalleryRepositoryError: Error, Equatable {
    case imageDataUnavailable(URL)
}

protocol GalleryRepository: Sendable {
    func loadInitialSnapshot() async throws -> GallerySnapshot
    func refreshSnapshot() async throws -> GallerySnapshot
    func imageData(for url: URL, variant: ImageDataVariant) async throws -> Data
    func metadata(for url: URL) async throws -> ImageMetadata
}

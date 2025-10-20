import Foundation

struct GalleryImage: Equatable, Hashable {
    let url: URL
    let originalLine: String
    let lineNumber: Int
}

enum GalleryPlaceholderReason: Equatable, Hashable {
    case nonImageURL
    case invalidContent
}

struct GalleryPlaceholder: Equatable, Hashable {
    let originalLine: String
    let lineNumber: Int
    let reason: GalleryPlaceholderReason
}

enum GalleryItem: Equatable, Hashable {
    case image(GalleryImage)
    case placeholder(GalleryPlaceholder)
}

struct GallerySnapshot: Equatable {
    let sourceURL: URL
    let fetchedAt: Date
    let items: [GalleryItem]

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

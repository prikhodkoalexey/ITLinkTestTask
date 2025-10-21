import XCTest
@testable import ITLinkTestTask

final class ImageViewerAssemblyTests: XCTestCase {
    private var assembly: ImageViewerAssembly!
    private var imageLoader: GalleryImageLoader!
    private let testURL = URL(string: "https://example.com/image.jpg")!

    override func setUp() {
        super.setUp()
        imageLoader = makeImageLoader()
        assembly = ImageViewerAssembly(galleryImageLoader: imageLoader)
    }

    override func tearDown() {
        assembly = nil
        imageLoader = nil
        super.tearDown()
    }

    func testMakeImageViewerViewController() {
        let viewController = assembly.makeImageViewerViewController(
            imageURL: testURL,
            allImageURLs: [testURL],
            currentIndex: 0
        )
        XCTAssertNotNil(viewController)
        XCTAssertTrue(viewController is ImageViewerViewController)
    }
}

private extension ImageViewerAssemblyTests {
    func makeImageLoader() -> GalleryImageLoader {
        let repository = StubGalleryRepository { _, _ in Data() }
        let useCase = FetchGalleryImageDataUseCase(repository: repository)
        return GalleryImageLoader(fetchImageData: useCase)
    }
}

private struct StubGalleryRepository: GalleryRepository {
    let imageDataProvider: @Sendable (URL, ImageDataVariant) async throws -> Data

    func loadInitialSnapshot() async throws -> GallerySnapshot {
        GallerySnapshot(
            sourceURL: URL(string: "https://example.com/links.txt")!,
            fetchedAt: Date(),
            items: []
        )
    }

    func refreshSnapshot() async throws -> GallerySnapshot {
        try await loadInitialSnapshot()
    }

    func imageData(for url: URL, variant: ImageDataVariant) async throws -> Data {
        try await imageDataProvider(url, variant)
    }

    func metadata(for url: URL) async throws -> ImageMetadata {
        ImageMetadata(format: .unknown, mimeType: nil, originalURL: url)
    }
}

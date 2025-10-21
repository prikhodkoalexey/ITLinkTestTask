import UIKit
import XCTest
@testable import ITLinkTestTask

final class ImageViewerAssemblyTests: XCTestCase {
    private var assembly: ImageViewerAssembly!
    private var imageLoader: StubGalleryImageLoader!
    private let testURL = URL(string: "https://example.com/image.jpg")!

    override func setUp() {
        super.setUp()
        imageLoader = StubGalleryImageLoader()
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

private final class StubGalleryImageLoader: GalleryImageLoading {
    func image(for url: URL, variant: ImageVariant) async throws -> UIImage {
        UIImage()
    }
}

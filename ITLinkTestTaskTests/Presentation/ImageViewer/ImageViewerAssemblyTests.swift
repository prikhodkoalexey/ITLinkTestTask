import XCTest
@testable import ITLinkTestTask

final class ImageViewerAssemblyTests: XCTestCase {
    private var assembly: ImageViewerAssembly!
    private var mockImageLoader: MockGalleryImageLoader!
    
    override func setUp() {
        super.setUp()
        mockImageLoader = MockGalleryImageLoader()
        assembly = ImageViewerAssembly(galleryImageLoader: mockImageLoader)
    }
    
    override func tearDown() {
        mockImageLoader = nil
        assembly = nil
        super.tearDown()
    }
    
    func testMakeImageViewerViewController() {
        
        let viewController = assembly.makeImageViewerViewController(imageURL: testURL)
        
        XCTAssertNotNil(viewController)
        XCTAssertTrue(viewController is ImageViewerViewController)
    }
    
    func testImageViewerViewControllerHasCorrectViewModel() {
        
        let viewController = assembly.makeImageViewerViewController(imageURL: testURL)
        
        XCTAssertNotNil(viewController.viewModel)
    }
}

private final class MockGalleryImageLoader: GalleryImageLoaderProtocol {
    func image(for url: URL, targetSize: CGSize, scale: CGFloat) async throws -> UIImage {
        throw GalleryImageLoader.ImageLoadingError.failed
    }
}
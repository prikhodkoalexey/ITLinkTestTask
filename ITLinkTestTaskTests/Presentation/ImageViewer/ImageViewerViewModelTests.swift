import XCTest
@testable import ITLinkTestTask

final class ImageViewerViewModelTests: XCTestCase {
    private var mockImageLoader: MockGalleryImageLoader!
    private var viewModel: ImageViewerViewModel!
    private var stateChanges: [ImageViewerViewState] = []
    
    override func setUp() {
        super.setUp()
        mockImageLoader = MockGalleryImageLoader()
        viewModel = ImageViewerViewModel(
            imageLoader: mockImageLoader,
        )
        
        viewModel.onStateChange = { [weak self] state in
            self?.stateChanges.append(state)
        }
        
        stateChanges = []
    }
    
    override func tearDown() {
        mockImageLoader = nil
        viewModel = nil
        stateChanges = []
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertTrue(stateChanges.isEmpty)
    }
    
    func testLoadImageSuccess() async throws {
        let testImage = UIImage(systemName: "photo")!
        mockImageLoader.stubbedImageResult = .success(testImage)
        
        viewModel.loadImage()
        
        XCTAssertEqual(stateChanges.count, 1)
        if case .loaded(let image) = stateChanges[0] {
            XCTAssertEqual(image, testImage)
        } else {
            XCTFail("Expected loaded state with image")
        }
    }
    
    func testLoadImageFailure() async throws {
        mockImageLoader.stubbedImageResult = .failure(GalleryImageLoader.ImageLoadingError.failed)
        
        viewModel.loadImage()
        
        XCTAssertEqual(stateChanges.count, 1)
        if case .error = stateChanges[0] {
        } else {
            XCTFail("Expected error state")
        }
    }
}

private final class MockGalleryImageLoader: GalleryImageLoaderProtocol {
    var stubbedImageResult: Result<UIImage, GalleryImageLoader.ImageLoadingError> = .failure(.failed)
    
    func image(for url: URL, targetSize: CGSize, scale: CGFloat) async throws -> UIImage {
        switch stubbedImageResult {
        case .success(let image):
            return image
        case .failure(let error):
            throw error
        }
    }
}
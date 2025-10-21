import UIKit
import XCTest
@testable import ITLinkTestTask

final class ImageViewerViewModelTests: XCTestCase {
    private let testURL = URL(string: "https://example.com/image.jpg")!

    func testInitialState() {
        let loader = StubGalleryImageLoader(result: .success(UIImage()))
        let viewModel = makeViewModel(loader: loader)
        var capturedStates: [ImageViewerViewState] = []
        viewModel.onStateChange = { state in
            capturedStates.append(state)
        }
        XCTAssertTrue(capturedStates.isEmpty)
    }

    func testLoadImageSuccess() {
        let expectation = expectation(description: "loaded")
        let stubImage = UIImage(systemName: "photo")!
        let loader = StubGalleryImageLoader(result: .success(stubImage))
        let viewModel = makeViewModel(loader: loader)
        var capturedStates: [ImageViewerViewState] = []
        viewModel.onStateChange = { state in
            capturedStates.append(state)
            expectation.fulfill()
        }
        viewModel.loadImage()
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(capturedStates.count, 1)
        if case .loaded(let image) = capturedStates[0] {
            XCTAssertEqual(image.pngData(), stubImage.pngData())
        } else {
            XCTFail("Expected loaded state with image")
        }
    }

    func testLoadImageFailure() {
        let expectation = expectation(description: "error")
        let loader = StubGalleryImageLoader(result: .failure(StubError.failed))
        let viewModel = makeViewModel(loader: loader)
        var capturedStates: [ImageViewerViewState] = []
        viewModel.onStateChange = { state in
            capturedStates.append(state)
            expectation.fulfill()
        }
        viewModel.loadImage()
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(capturedStates.count, 1)
        if case .error = capturedStates[0] {
        } else {
            XCTFail("Expected error state")
        }
    }
}

private extension ImageViewerViewModelTests {
    func makeViewModel(loader: GalleryImageLoading) -> ImageViewerViewModel {
        ImageViewerViewModel(
            imageLoader: loader,
            imageURL: testURL,
            allImageURLs: [testURL],
            currentIndex: 0
        )
    }
}

private enum StubError: Error {
    case failed
}

private final class StubGalleryImageLoader: GalleryImageLoading {
    var result: Result<UIImage, Error>

    init(result: Result<UIImage, Error>) {
        self.result = result
    }

    func image(for url: URL, variant: ImageVariant) async throws -> UIImage {
        switch result {
        case .success(let image):
            return image
        case .failure(let error):
            throw error
        }
    }
}

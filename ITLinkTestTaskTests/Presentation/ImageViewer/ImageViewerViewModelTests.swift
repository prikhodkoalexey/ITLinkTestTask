import UIKit
import XCTest
@testable import ITLinkTestTask

@MainActor
final class ImageViewerViewModelTests: XCTestCase {
    private let firstURL = URL(string: "https://example.com/first.jpg")!
    private let secondURL = URL(string: "https://example.com/second.jpg")!

    func testInitialStateIsIdle() {
        let loader = StubGalleryImageLoader(responses: [:])
        let viewModel = makeViewModel(loader: loader)
        let state = viewModel.state(at: 0)
        if case .idle = state {
        } else {
            XCTFail("Expected idle state")
        }
    }

    func testStartLoadsImageSuccessfully() {
        let image = UIImage(systemName: "photo")!
        let loader = StubGalleryImageLoader(responses: [firstURL: .success(image)])
        let viewModel = makeViewModel(loader: loader)
        var captured: [ImageViewerPageState] = []
        let expectation = expectation(description: "loaded")
        viewModel.onPageStateChange = { index, state in
            guard index == 0 else { return }
            captured.append(state)
            if case .loaded = state {
                expectation.fulfill()
            }
        }
        viewModel.start()
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(captured.count, 2)
        if case .loading(let existing) = captured.first {
            XCTAssertNil(existing)
        } else {
            XCTFail("Expected loading state first")
        }
        if case .loaded(let loadedImage) = captured.last {
            XCTAssertEqual(loadedImage.pngData(), image.pngData())
        } else {
            XCTFail("Expected loaded state last")
        }
    }

    func testStartHandlesError() {
        let loader = StubGalleryImageLoader(responses: [firstURL: .failure(StubError.failed)])
        let viewModel = makeViewModel(loader: loader)
        let expectation = expectation(description: "failed")
        viewModel.onPageStateChange = { index, state in
            guard index == 0 else { return }
            if case .failed = state {
                expectation.fulfill()
            }
        }
        viewModel.start()
        wait(for: [expectation], timeout: 1)
        let state = viewModel.state(at: 0)
        if case .failed = state {
        } else {
            XCTFail("Expected failed state")
        }
    }

    func testRetryAfterFailure() {
        let loader = StubGalleryImageLoader(responses: [firstURL: .failure(StubError.failed)])
        let viewModel = makeViewModel(loader: loader)
        let failureExpectation = expectation(description: "failed")
        viewModel.onPageStateChange = { index, state in
            guard index == 0 else { return }
            if case .failed = state {
                failureExpectation.fulfill()
            }
        }
        viewModel.start()
        wait(for: [failureExpectation], timeout: 1)

        let image = UIImage(systemName: "star")!
        loader.updateResponse(.success(image), for: firstURL)
        var captured: [ImageViewerPageState] = []
        let successExpectation = expectation(description: "loaded")
        viewModel.onPageStateChange = { index, state in
            guard index == 0 else { return }
            captured.append(state)
            if case .loaded = state {
                successExpectation.fulfill()
            }
        }
        viewModel.retryItem(at: 0)
        wait(for: [successExpectation], timeout: 1)
        XCTAssertTrue(captured.contains { state in
            if case .loading = state { return true }
            return false
        })
        XCTAssertTrue(captured.contains { state in
            if case .loaded(let loadedImage) = state {
                return loadedImage.pngData() == image.pngData()
            }
            return false
        })
    }

    func testStartPrefetchesNextImage() {
        let loader = StubGalleryImageLoader(responses: [
            firstURL: .success(UIImage()),
            secondURL: .success(UIImage())
        ])
        let viewModel = makeViewModel(loader: loader)
        let expectation = expectation(description: "prefetch next")
        viewModel.onPageStateChange = { index, state in
            if index == 1, case .loading = state {
                expectation.fulfill()
            }
        }
        viewModel.start()
        wait(for: [expectation], timeout: 1)
    }
}

private extension ImageViewerViewModelTests {
    func makeViewModel(loader: GalleryImageLoading) -> ImageViewerViewModel {
        ImageViewerViewModel(
            imageLoader: loader,
            imageURL: firstURL,
            allImageURLs: [firstURL, secondURL],
            currentIndex: 0
        )
    }
}

private enum StubError: Error {
    case failed
}

private final class StubGalleryImageLoader: GalleryImageLoading {
    private var responses: [URL: Result<UIImage, Error>]
    private let lock = NSLock()

    init(responses: [URL: Result<UIImage, Error>]) {
        self.responses = responses
    }

    func updateResponse(_ result: Result<UIImage, Error>, for url: URL) {
        lock.lock()
        responses[url] = result
        lock.unlock()
    }

    func image(for url: URL, variant: ImageVariant) async throws -> UIImage {
        let response: Result<UIImage, Error>?
        lock.lock()
        response = responses[url]
        lock.unlock()
        switch response {
        case .success(let image):
            return image
        case .failure(let error):
            throw error
        case .none:
            throw StubError.failed
        }
    }
}

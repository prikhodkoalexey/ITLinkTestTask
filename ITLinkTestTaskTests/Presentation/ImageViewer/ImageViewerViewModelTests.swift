import UIKit
import XCTest
@testable import ITLinkTestTask

final class ImageViewerViewModelTests: XCTestCase {
    private let testURL = URL(string: "https://example.com/image.jpg")!

    func testInitialState() {
        let viewModel = makeViewModel(result: .success(Data()))
        var capturedStates: [ImageViewerViewState] = []
        viewModel.onStateChange = { state in
            capturedStates.append(state)
        }
        XCTAssertTrue(capturedStates.isEmpty)
    }

    func testLoadImageSuccess() {
        let expectation = expectation(description: "loaded")
        let imageData = UIImage(systemName: "photo")!.pngData()!
        let viewModel = makeViewModel(result: .success(imageData))
        var capturedStates: [ImageViewerViewState] = []
        viewModel.onStateChange = { state in
            capturedStates.append(state)
            expectation.fulfill()
        }
        viewModel.loadImage()
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(capturedStates.count, 1)
        if case .loaded(let image) = capturedStates[0] {
            XCTAssertNotNil(image)
        } else {
            XCTFail("Expected loaded state with image")
        }
    }

    func testLoadImageFailure() {
        let expectation = expectation(description: "error")
        let viewModel = makeViewModel(result: .failure(StubError.failed))
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
    func makeViewModel(result: Result<Data, Error>) -> ImageViewerViewModel {
        let repository = StubGalleryRepository { url, _ in
            switch result {
            case .success(let data):
                return data
            case .failure(let error):
                throw error
            }
        }
        let useCase = FetchGalleryImageDataUseCase(repository: repository)
        let imageLoader = GalleryImageLoader(fetchImageData: useCase)
        return ImageViewerViewModel(
            imageLoader: imageLoader,
            imageURL: testURL,
            allImageURLs: [testURL],
            currentIndex: 0
        )
    }
}

private enum StubError: Error {
    case failed
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

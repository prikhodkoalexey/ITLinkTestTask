import UIKit
import Foundation

enum ImageViewerViewState {
    case loading
    case loaded(UIImage)
    case error
}

final class ImageViewerViewModel {
    private let imageLoader: GalleryImageLoading
    private let imageURL: URL
    private let allImageURLs: [URL]
    private let currentIndex: Int
    private var loadTask: Task<Void, Never>?

    var onStateChange: ((ImageViewerViewState) -> Void)?
    var onImageLoaded: (() -> Void)?
    
    init(
        imageLoader: GalleryImageLoading,
        imageURL: URL,
        allImageURLs: [URL],
        currentIndex: Int
    ) {
        self.imageLoader = imageLoader
        self.imageURL = imageURL
        self.allImageURLs = allImageURLs
        self.currentIndex = currentIndex
    }
    
    func loadImage() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            await performLoad()
        }
    }
    
    func getImageURL(forIndex index: Int) -> URL? {
        guard index >= 0, index < allImageURLs.count else { return nil }
        return allImageURLs[index]
    }
    
    func hasPreviousImage() -> Bool {
        return currentIndex > 0
    }
    
    func hasNextImage() -> Bool {
        return currentIndex < allImageURLs.count - 1
    }
    
    func goToPreviousImage() -> ImageViewerViewModel? {
        guard hasPreviousImage() else { return nil }
        let newIndex = currentIndex - 1
        return ImageViewerViewModel(
            imageLoader: imageLoader,
            imageURL: allImageURLs[newIndex],
            allImageURLs: allImageURLs,
            currentIndex: newIndex
        )
    }
    
    func goToNextImage() -> ImageViewerViewModel? {
        guard hasNextImage() else { return nil }
        let newIndex = currentIndex + 1
        return ImageViewerViewModel(
            imageLoader: imageLoader,
            imageURL: allImageURLs[newIndex],
            allImageURLs: allImageURLs,
            currentIndex: newIndex
        )
    }
    
    var currentIndexInGallery: Int {
        return currentIndex
    }
    
    var totalImagesCount: Int {
        return allImageURLs.count
    }
    
    private func performLoad() async {
        do {
            let image = try await imageLoader.image(
                for: imageURL,
                variant: .original
            )
            await MainActor.run {
                onStateChange?(.loaded(image))
                onImageLoaded?()
            }
        } catch {
            await MainActor.run {
                onStateChange?(.error)
            }
        }
    }

    deinit {
        loadTask?.cancel()
    }
}

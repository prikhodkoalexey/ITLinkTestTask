import UIKit
import Foundation

enum ImageViewerViewState {
    case loading
    case loaded(UIImage)
    case error
}

final class ImageViewerViewModel {
    private let imageLoader: GalleryImageLoader
    private let imageURL: URL
    
    var onStateChange: ((ImageViewerViewState) -> Void)?
    
    init(
        imageLoader: GalleryImageLoader,
        imageURL: URL
    ) {
        self.imageLoader = imageLoader
        self.imageURL = imageURL
    }
    
    func loadImage() {
        Task {
            await performLoad()
        }
    }
    
    private func performLoad() async {
        do {
            let image = try await imageLoader.image(
                for: imageURL,
                targetSize: UIScreen.main.bounds.size,
                scale: UIScreen.main.scale
            )
            await MainActor.run {
                onStateChange?(.loaded(image))
            }
        } catch {
            await MainActor.run {
                onStateChange?(.error)
            }
        }
    }
}
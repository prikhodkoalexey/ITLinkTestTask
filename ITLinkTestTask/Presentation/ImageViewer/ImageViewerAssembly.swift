import Foundation

struct ImageViewerAssembly {
    private let galleryImageLoader: GalleryImageLoader
    
    init(
        galleryImageLoader: GalleryImageLoader
    ) {
        self.galleryImageLoader = galleryImageLoader
    }
    
    func makeImageViewerViewController(imageURL: URL) -> ImageViewerViewController {
        let viewModel = ImageViewerViewModel(
            imageLoader: galleryImageLoader,
            imageURL: imageURL
        )
        return ImageViewerViewController(viewModel: viewModel)
    }
}
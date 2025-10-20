import Foundation

struct ImageViewerAssembly {
    private let galleryImageLoader: GalleryImageLoader
    
    init(
        galleryImageLoader: GalleryImageLoader
    ) {
        self.galleryImageLoader = galleryImageLoader
    }
    
    func makeImageViewerViewController(imageURL: URL, allImageURLs: [URL], currentIndex: Int) -> ImageViewerViewController {
        let viewModel = ImageViewerViewModel(
            imageLoader: galleryImageLoader,
            imageURL: imageURL,
            allImageURLs: allImageURLs,
            currentIndex: currentIndex
        )
        return ImageViewerViewController(viewModel: viewModel)
    }
}
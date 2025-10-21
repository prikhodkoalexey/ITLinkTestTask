import Foundation

struct ImageViewerAssembly {
    private let galleryImageLoader: GalleryImageLoading

    init(
        galleryImageLoader: GalleryImageLoading
    ) {
        self.galleryImageLoader = galleryImageLoader
    }
    
    func makeImageViewerViewController(
        imageURL: URL,
        allImageURLs: [URL],
        currentIndex: Int
    ) -> ImageViewerViewController {
        let viewModel = ImageViewerViewModel(
            imageLoader: galleryImageLoader,
            imageURL: imageURL,
            allImageURLs: allImageURLs,
            currentIndex: currentIndex
        )
        return ImageViewerViewController(viewModel: viewModel)
    }
}

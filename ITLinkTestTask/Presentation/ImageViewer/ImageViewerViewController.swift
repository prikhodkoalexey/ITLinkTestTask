import UIKit

final class ImageViewerViewController: UIViewController {
    private var viewModel: ImageViewerViewModel
    
    private let pageScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = false
        scrollView.backgroundColor = .black
        return scrollView
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Назад", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(
            top: ImageViewerLayoutConstants.ButtonInsets.top,
            left: ImageViewerLayoutConstants.ButtonInsets.left,
            bottom: ImageViewerLayoutConstants.ButtonInsets.bottom,
            right: ImageViewerLayoutConstants.ButtonInsets.right
        )
        button.accessibilityIdentifier = Accessibility.backButton
        return button
    }()
    
    private let fullscreenButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = ImageViewerLayoutConstants.fullscreenButtonSize.width / 2
        button.contentEdgeInsets = UIEdgeInsets(
            top: ImageViewerLayoutConstants.ButtonInsets.top,
            left: ImageViewerLayoutConstants.ButtonInsets.left,
            bottom: ImageViewerLayoutConstants.ButtonInsets.bottom,
            right: ImageViewerLayoutConstants.ButtonInsets.right
        )
        button.setImage(UIImage(systemName: "arrow.up.backward.and.arrow.down.forward"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        return button
    }()
    
    private let shareButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = ImageViewerLayoutConstants.shareButtonSize.width / 2
        button.contentEdgeInsets = UIEdgeInsets(
            top: ImageViewerLayoutConstants.ButtonInsets.top,
            left: ImageViewerLayoutConstants.ButtonInsets.left,
            bottom: ImageViewerLayoutConstants.ButtonInsets.bottom,
            right: ImageViewerLayoutConstants.ButtonInsets.right
        )
        button.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        return button
    }()
    
    private let pageControl: UIPageControl = {
        let pageControl = UIPageControl()
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.4)
        pageControl.currentPageIndicatorTintColor = .white
        return pageControl
    }()
    
    private var imageScrollViews: [UIScrollView] = []
    private var imageViews: [UIImageView] = []
    private var tapGestureRecognizer: UITapGestureRecognizer!
    private var doubleTapGestureRecognizer: UITapGestureRecognizer!
    
    private var isFullscreen = false {
        didSet {
            updateFullscreenState()
        }
    }
    
    init(viewModel: ImageViewerViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupConstraints()
        setupActions()
        bind(to: viewModel)
        
        setupPages()
        updatePageControl()
        viewModel.loadImage()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        UIView.performWithoutAnimation {
            updatePageContentSize()
            scrollToPage(index: viewModel.currentIndexInGallery, animated: false)
            updateZoomScalesForImages()
        }
    }
    
    private func setupView() {
        view.backgroundColor = .black
        view.addSubview(pageScrollView)
        view.addSubview(activityIndicator)
        view.addSubview(backButton)
        view.addSubview(fullscreenButton)
        view.addSubview(shareButton)
        view.addSubview(pageControl)
        
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGestureRecognizer.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGestureRecognizer)
        
        doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
        tapGestureRecognizer.require(toFail: doubleTapGestureRecognizer)
        view.addGestureRecognizer(doubleTapGestureRecognizer)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            pageScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            pageScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            backButton.topAnchor
                .constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: ImageViewerLayoutConstants.backButtonTopOffset),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: ImageViewerLayoutConstants.backButtonLeadingOffset),
            
            fullscreenButton.topAnchor
                .constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: ImageViewerLayoutConstants.fullscreenButtonTopOffset),
            fullscreenButton.trailingAnchor
                .constraint(equalTo: view.trailingAnchor, constant: ImageViewerLayoutConstants.fullscreenButtonTrailingOffset),
            fullscreenButton.widthAnchor
                .constraint(equalToConstant: ImageViewerLayoutConstants.fullscreenButtonSize.width),
            fullscreenButton.heightAnchor
                .constraint(equalToConstant: ImageViewerLayoutConstants.fullscreenButtonSize.height),
            
            shareButton.topAnchor
                .constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: ImageViewerLayoutConstants.shareButtonTopOffset),
            shareButton.trailingAnchor
                .constraint(equalTo: fullscreenButton.leadingAnchor, constant: -ImageViewerLayoutConstants.shareButtonSpacing),
            shareButton.widthAnchor
                .constraint(equalToConstant: ImageViewerLayoutConstants.shareButtonSize.width),
            shareButton.heightAnchor
                .constraint(equalToConstant: ImageViewerLayoutConstants.shareButtonSize.height),
            
            pageControl.bottomAnchor
                .constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -ImageViewerLayoutConstants.pageControlBottomOffset),
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    private func setupActions() {
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        fullscreenButton.addTarget(self, action: #selector(fullscreenButtonTapped), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        pageScrollView.delegate = self
        pageControl.addTarget(self, action: #selector(pageControlValueChanged), for: .valueChanged)
    }
    
    private func bind(to viewModel: ImageViewerViewModel) {
        viewModel.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleViewModelState(state)
            }
        }
        
        viewModel.onImageLoaded = { [weak self] in
            DispatchQueue.main.async {
                self?.updatePageControl()
            }
        }
    }
    
    private func setupPages() {
        let totalImages = viewModel.totalImagesCount
        imageScrollViews.removeAll()
        imageViews.removeAll()
        
        pageScrollView.subviews.forEach { $0.removeFromSuperview() }
        
        for _ in 0..<totalImages {
            let scrollContainer = createScrollView()
            let imageView = createImageView()

            scrollContainer.addSubview(imageView)
            pageScrollView.addSubview(scrollContainer)

            imageScrollViews.append(scrollContainer)
            imageViews.append(imageView)
        }
    }
    
    private func createScrollView() -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .black
        return scrollView
    }
    
    private func createImageView() -> UIImageView {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = true
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .systemBackground
        return imageView
    }
    
    private func updatePageContentSize() {
        pageScrollView.contentSize = CGSize(
            width: pageScrollView.bounds.width * CGFloat(imageViews.count),
            height: pageScrollView.bounds.height
        )
        
        for (index, scrollView) in imageScrollViews.enumerated() {
            scrollView.frame = CGRect(
                x: CGFloat(index) * pageScrollView.bounds.width,
                y: 0,
                width: pageScrollView.bounds.width,
                height: pageScrollView.bounds.height
            )
        }
    }
    
    private func scrollToPage(index: Int, animated: Bool) {
        let pageOffset = CGFloat(index) * pageScrollView.bounds.width
        pageScrollView.setContentOffset(CGPoint(x: pageOffset, y: 0), animated: animated)
    }
    
    private func updatePageControl() {
        pageControl.numberOfPages = viewModel.totalImagesCount
        pageControl.currentPage = viewModel.currentIndexInGallery
        pageControl.isHidden = viewModel.totalImagesCount <= 1
    }
    
    private func handleViewModelState(_ state: ImageViewerViewState) {
        let currentScrollView = imageScrollViews[viewModel.currentIndexInGallery]
        let currentImageView = imageViews[viewModel.currentIndexInGallery]
        
        switch state {
        case .loading:
            activityIndicator.startAnimating()
            currentImageView.image = nil
        case .loaded(let image):
            activityIndicator.stopAnimating()
            currentImageView.image = image
            setupZoomForImage(scrollView: currentScrollView, imageView: currentImageView, image: image)
        case .error:
            activityIndicator.stopAnimating()
        }
    }
    
    private func updateZoomScalesForImages() {
        guard imageScrollViews.count == imageViews.count else { return }
        for index in 0..<imageScrollViews.count {
            let scrollView = imageScrollViews[index]
            let imageView = imageViews[index]
            guard let image = imageView.image else { continue }
            setupZoomForImage(scrollView: scrollView, imageView: imageView, image: image)
        }
    }

    private func setupZoomForImage(scrollView: UIScrollView, imageView: UIImageView, image: UIImage) {
        let scrollViewSize = scrollView.bounds.size
        guard scrollViewSize.width > 0, scrollViewSize.height > 0 else {
            return
        }

        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else {
            return
        }
        let widthScale = scrollViewSize.width / imageSize.width
        let heightScale = scrollViewSize.height / imageSize.height
        let fitScale = min(widthScale, heightScale)
        
        let fittedSize = CGSize(
            width: imageSize.width * fitScale,
            height: imageSize.height * fitScale
        )
        imageView.frame = CGRect(origin: .zero, size: fittedSize)
        
        scrollView.contentSize = fittedSize
        
        let minimumZoomScale = min(widthScale, heightScale)
        
        scrollView.minimumZoomScale = minimumZoomScale
        scrollView.maximumZoomScale = max(minimumZoomScale * 3, 3)

        if scrollView.zoomScale != scrollView.minimumZoomScale {
            scrollView.zoomScale = scrollView.minimumZoomScale
        }
        
        let verticalInset = max(0, (scrollViewSize.height - imageView.frame.height) / 2)
        let horizontalInset = max(0, (scrollViewSize.width - imageView.frame.width) / 2)
        scrollView.contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
        scrollView.contentOffset = CGPoint(x: -horizontalInset, y: -verticalInset)
    }
    
    private func updateFullscreenState() {
        let systemName = isFullscreen ? "arrow.down.forward.and.arrow.up.backward" : "arrow.up.backward.and.arrow.down.forward"
        let image = UIImage(systemName: systemName)
        fullscreenButton.setImage(image, for: .normal)
        
        UIView.animate(withDuration: 0.3) {
            self.navigationController?.setNavigationBarHidden(self.isFullscreen, animated: true)
            self.setNeedsStatusBarAppearanceUpdate()
            
            self.backButton.alpha = self.isFullscreen ? 0 : 1
            self.fullscreenButton.alpha = self.isFullscreen ? 0 : 1
            self.pageControl.alpha = self.isFullscreen ? 0 : 1
        }
    }
    
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func fullscreenButtonTapped() {
        isFullscreen.toggle()
    }
    
    @objc private func handleTap() {
        isFullscreen.toggle()
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let currentScrollView = imageScrollViews[pageControl.currentPage]
        if currentScrollView.zoomScale > currentScrollView.minimumZoomScale {
            currentScrollView.setZoomScale(currentScrollView.minimumZoomScale, animated: true)
        } else {
            let location = gesture.location(in: imageViews[pageControl.currentPage])
            let zoomRect = zoomRectForScale(
                scale: currentScrollView.maximumZoomScale,
                center: location
            )
            currentScrollView.zoom(to: zoomRect, animated: true)
        }
    }
    
    private func zoomRectForScale(scale: CGFloat, center: CGPoint) -> CGRect {
        let currentScrollView = imageScrollViews[pageControl.currentPage]
        let width = currentScrollView.frame.width / scale
        let height = currentScrollView.frame.height / scale
        return CGRect(
            x: center.x - width / 2,
            y: center.y - height / 2,
            width: width,
            height: height
        )
    }
    
    @objc private func shareButtonTapped() {
        let currentImageURL = viewModel.getImageURL(forIndex: pageControl.currentPage)
        guard let url = currentImageURL else { return }
        
        let activityViewController = UIActivityViewController(activityItems: [url.absoluteString], applicationActivities: nil)
        
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        
        present(activityViewController, animated: true)
    }
    
    @objc private func pageControlValueChanged() {
        scrollToPage(index: pageControl.currentPage, animated: true)
    }
    
    override var prefersStatusBarHidden: Bool {
        return isFullscreen
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .fade
    }
}

extension ImageViewerViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == pageScrollView {
            let width = scrollView.bounds.width
            guard width.isFinite, width > 0 else { return }
            let pageIndex = round(scrollView.contentOffset.x / width)
            guard pageIndex.isFinite else { return }
            guard pageControl.numberOfPages > 0 else { return }
            let clampedIndex = max(0, min(Int(pageIndex), pageControl.numberOfPages - 1))
            if pageControl.currentPage != clampedIndex {
                pageControl.currentPage = clampedIndex
            }
        }
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        for (index, imageScrollView) in imageScrollViews.enumerated() where scrollView == imageScrollView {
            return imageViews[index]
        }
        return nil
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        for (index, imageScrollView) in imageScrollViews.enumerated() where scrollView == imageScrollView {
            let imageView = imageViews[index]
            let scrollViewSize = scrollView.bounds.size
            let imageViewSize = imageView.frame.size
            
            let verticalInset = max(0, (scrollViewSize.height - imageViewSize.height) / 2)
            let horizontalInset = max(0, (scrollViewSize.width - imageViewSize.width) / 2)
            
            scrollView.contentInset = UIEdgeInsets(
                top: verticalInset,
                left: horizontalInset,
                bottom: verticalInset,
                right: horizontalInset
            )
        }
    }
}

private enum ImageViewerLayoutConstants {
    static let backButtonTopOffset: CGFloat = 16
    static let backButtonLeadingOffset: CGFloat = 16
    static let fullscreenButtonTopOffset: CGFloat = 16
    static let fullscreenButtonTrailingOffset: CGFloat = -16
    static let fullscreenButtonSize = CGSize(width: 44, height: 44)
    static let shareButtonTopOffset: CGFloat = 16
    static let shareButtonSpacing: CGFloat = 16
    static let shareButtonSize = CGSize(width: 44, height: 44)
    static let pageControlBottomOffset: CGFloat = 16
    
    enum ButtonInsets {
        static let top: CGFloat = 8
        static let left: CGFloat = 16
        static let bottom: CGFloat = 8
        static let right: CGFloat = 16
    }
}

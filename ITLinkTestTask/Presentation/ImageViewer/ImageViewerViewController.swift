import UIKit

final class ImageViewerViewController: UIViewController {
    private let viewModel: ImageViewerViewModel
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.zoomScale = 1.0
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        return scrollView
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .systemBackground
        return imageView
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
    
    private var isFullscreen = false {
        didSet {
            updateFullscreenState()
        }
    }
    
    private var tapGestureRecognizer: UITapGestureRecognizer!
    
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
        
        viewModel.loadImage()
    }
    
    private func setupView() {
        view.backgroundColor = .black
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        view.addSubview(activityIndicator)
        view.addSubview(backButton)
        view.addSubview(fullscreenButton)
        
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGestureRecognizer.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGestureRecognizer)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            backButton.topAnchor
                .constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: ImageViewerLayoutConstants.backButtonTopOffset),
            backButton.leadingAnchor
                .constraint(equalTo: view.leadingAnchor, constant: ImageViewerLayoutConstants.backButtonLeadingOffset),
            
            fullscreenButton.topAnchor
                .constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: ImageViewerLayoutConstants.fullscreenButtonTopOffset),
            fullscreenButton.trailingAnchor
                .constraint(equalTo: view.trailingAnchor, constant: ImageViewerLayoutConstants.fullscreenButtonTrailingOffset),
            fullscreenButton.widthAnchor
                .constraint(equalToConstant: ImageViewerLayoutConstants.fullscreenButtonSize.width),
            fullscreenButton.heightAnchor
                .constraint(equalToConstant: ImageViewerLayoutConstants.fullscreenButtonSize.height)
        ])
    }
    
    private func setupActions() {
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        fullscreenButton.addTarget(self, action: #selector(fullscreenButtonTapped), for: .touchUpInside)
        scrollView.delegate = self
    }
    
    private func bind(to viewModel: ImageViewerViewModel) {
        viewModel.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleViewModelState(state)
            }
        }
    }
    
    private func handleViewModelState(_ state: ImageViewerViewState) {
        switch state {
        case .loading:
            activityIndicator.startAnimating()
            imageView.image = nil
        case .loaded(let image):
            activityIndicator.stopAnimating()
            imageView.image = image
            setupZoomForImage()
        case .error:
            activityIndicator.stopAnimating()
        }
    }
    
    private func setupZoomForImage() {
        guard let image = imageView.image else { return }
        
        let imageViewSize = image.size
        let aspectRatio = imageViewSize.width / imageViewSize.height
        
        let scrollViewSize = scrollView.bounds.size
        let scrollViewRatio = scrollViewSize.width / scrollViewSize.height
        
        if aspectRatio > scrollViewRatio {
            let width = scrollViewSize.width
            let height = width / aspectRatio
            imageView.frame = CGRect(x: 0, y: (scrollViewSize.height - height) / 2, width: width, height: height)
        } else {
            let height = scrollViewSize.height
            let width = height * aspectRatio
            imageView.frame = CGRect(x: (scrollViewSize.width - width) / 2, y: 0, width: width, height: height)
        }
        
        scrollView.contentSize = imageView.frame.size
        scrollView.minimumZoomScale = min(scrollViewSize.width / imageView.frame.width, scrollViewSize.height / imageView.frame.height)
        scrollView.minimumZoomScale = min(scrollView.minimumZoomScale, 1.0)
        scrollView.zoomScale = scrollView.minimumZoomScale
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
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return isFullscreen
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .fade
    }
    
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func fullscreenButtonTapped() {
        isFullscreen.toggle()
    }
    
    @objc private func handleTap() {
        if isFullscreen {
            isFullscreen = false
        } else {
            isFullscreen = true
        }
    }
}

extension ImageViewerViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
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

private enum ImageViewerLayoutConstants {
    static let backButtonTopOffset: CGFloat = 16
    static let backButtonLeadingOffset: CGFloat = 16
    static let fullscreenButtonTopOffset: CGFloat = 16
    static let fullscreenButtonTrailingOffset: CGFloat = -16
    static let fullscreenButtonSize = CGSize(width: 44, height: 44)
    
    enum ButtonInsets {
        static let top: CGFloat = 8
        static let left: CGFloat = 16
        static let bottom: CGFloat = 8
        static let right: CGFloat = 16
    }
}

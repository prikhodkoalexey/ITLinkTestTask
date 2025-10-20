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
            top: LayoutConstants.ButtonInsets.top,
            left: LayoutConstants.ButtonInsets.left,
            bottom: LayoutConstants.ButtonInsets.bottom,
            right: LayoutConstants.ButtonInsets.right
        )
        return button
    }()
    
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
            
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: LayoutConstants.backButtonTopOffset),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: LayoutConstants.backButtonLeadingOffset)
        ])
    }
    
    private func setupActions() {
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
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
    
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
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

private extension ImageViewerViewController {
    enum LayoutConstants {
        static let backButtonTopOffset: CGFloat = 16
        static let backButtonLeadingOffset: CGFloat = 16
        
        enum ButtonInsets {
            static let top: CGFloat = 8
            static let left: CGFloat = 16
            static let bottom: CGFloat = 8
            static let right: CGFloat = 16
        }
    }
}
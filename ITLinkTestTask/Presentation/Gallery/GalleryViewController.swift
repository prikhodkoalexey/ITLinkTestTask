import UIKit

final class GalleryViewController: UIViewController {
    let viewModel: GalleryViewModel
    let imageLoader: GalleryImageLoading
    let reachability: ReachabilityService

    let layout = UICollectionViewFlowLayout()
    lazy var dataSource = makeDataSource()
    lazy var collectionView: UICollectionView = {
        layout.minimumLineSpacing = LayoutConstants.spacing
        layout.minimumInteritemSpacing = LayoutConstants.spacing
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemBackground
        collectionView.alwaysBounceVertical = true
        collectionView.register(GalleryImageCell.self, forCellWithReuseIdentifier: GalleryImageCell.reuseIdentifier)
        collectionView.register(
            GalleryPlaceholderCell.self,
            forCellWithReuseIdentifier: GalleryPlaceholderCell.reuseIdentifier
        )
        collectionView.refreshControl = refreshControl
        return collectionView
    }()

    let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    let messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        label.accessibilityIdentifier = Accessibility.errorLabel
        return label
    }()

    lazy var retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Повторить", for: .normal)
        button.addTarget(self, action: #selector(handleRetry), for: .touchUpInside)
        button.isHidden = true
        button.accessibilityIdentifier = Accessibility.retryButton
        return button
    }()

    lazy var statusStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [messageLabel, retryButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.isHidden = true
        return stack
    }()

    let refreshControl = UIRefreshControl()
    var tasks: [Task<Void, Never>] = []
    var imageTasks: [IndexPath: Task<Void, Never>] = [:]
    var currentItems: [GalleryItem] = []
    var isReachabilityMonitoring = false
    var failedThumbnailURLs: Set<URL> = []

    init(
        viewModel: GalleryViewModel,
        imageLoader: GalleryImageLoading,
        reachability: ReachabilityService
    ) {
        self.viewModel = viewModel
        self.imageLoader = imageLoader
        self.reachability = reachability
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Галерея"
        view.backgroundColor = .systemBackground
        setupHierarchy()
        setupConstraints()
        bindActions()
        bindViewModel()
        collectionView.delegate = self
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateItemSize(for: view.bounds.inset(by: view.safeAreaInsets).width)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        collectionView.backgroundColor = .systemBackground
        view.backgroundColor = .systemBackground
    }

    deinit {
        tasks.forEach { $0.cancel() }
        imageTasks.values.forEach { $0.cancel() }
        stopReachabilityMonitoring()
    }
}

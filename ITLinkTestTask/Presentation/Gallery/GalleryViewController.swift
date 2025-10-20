import UIKit

final class GalleryViewController: UIViewController {
    private enum Section {
        case main
    }

    private let viewModel: GalleryViewModel
    private let imageLoader: GalleryImageLoader
    private let reachability: ReachabilityService

    private let layout = UICollectionViewFlowLayout()
    private lazy var dataSource = makeDataSource()
    private lazy var collectionView: UICollectionView = {
        layout.minimumLineSpacing = Constants.spacing
        layout.minimumInteritemSpacing = Constants.spacing
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

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Повторить", for: .normal)
        button.addTarget(self, action: #selector(handleRetry), for: .touchUpInside)
        button.isHidden = true
        return button
    }()

    private lazy var statusStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [messageLabel, retryButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.isHidden = true
        return stack
    }()

    private let refreshControl = UIRefreshControl()
    private var tasks: [Task<Void, Never>] = []
    private var imageTasks: [IndexPath: Task<Void, Never>] = [:]
    private var isReachabilityMonitoring = false

    init(
        viewModel: GalleryViewModel,
        imageLoader: GalleryImageLoader,
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

    private func setupHierarchy() {
        view.addSubview(collectionView)
        view.addSubview(activityIndicator)
        view.addSubview(statusStackView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            statusStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusStackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.leadingAnchor),
            statusStackView.trailingAnchor.constraint(lessThanOrEqualTo: view.layoutMarginsGuide.trailingAnchor)
        ])
    }

    private func bindActions() {
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
    }

    private func bindViewModel() {
        viewModel.onStateChange = { [weak self] state in
            guard let self else { return }
            self.apply(state: state)
        }
        apply(state: viewModel.state)
        startTask { [weak self] in
            await self?.viewModel.loadInitialSnapshot()
        }
    }

    @MainActor
    private func apply(state: GalleryViewState) {
        if state.isRefreshing {
            if !refreshControl.isRefreshing {
                refreshControl.beginRefreshing()
            }
        } else {
            refreshControl.endRefreshing()
        }

        if state.isLoading && state.content == .empty {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }

        let items: [Item]
        switch state.content {
        case .empty:
            items = []
        case let .snapshot(snapshot):
            items = snapshot.items.map { item in
                switch item {
                case let .image(image):
                    return .image(image)
                case let .placeholder(placeholder):
                    return .placeholder(placeholder)
                }
            }
        }
        applySnapshot(with: items)

        if let error = state.error {
            showMessage(error.message, showRetry: error.isRetryAvailable)
        } else if items.isEmpty && !state.isLoading {
            showMessage("Ничего не найдено", showRetry: false)
        } else {
            hideMessage()
        }

        if case .empty = state.content, state.error != nil {
            startReachabilityMonitoring()
        } else {
            stopReachabilityMonitoring()
        }

        collectionView.isHidden = state.isLoading && state.content == .empty
    }

    private func updateItemSize(for availableWidth: CGFloat) {
        guard availableWidth > 0 else { return }
        let configuration = makeGridConfiguration(for: availableWidth)
        layout.sectionInset = configuration.insets
        layout.itemSize = CGSize(
            width: configuration.itemWidth,
            height: configuration.itemWidth
        )
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, Item> {
        UICollectionViewDiffableDataSource(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            switch item {
            case let .image(image):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: GalleryImageCell.reuseIdentifier,
                    for: indexPath
                ) as? GalleryImageCell
                cell?.configure(image: nil, accessibilityLabel: image.originalLine)
                return cell
            case let .placeholder(placeholder):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: GalleryPlaceholderCell.reuseIdentifier,
                    for: indexPath
                ) as? GalleryPlaceholderCell
                cell?.configure(with: placeholder)
                return cell
            }
        }
    }

    private func applySnapshot(with items: [Item]) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.main])
        snapshot.appendItems(items, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: true) { [weak self] in
            guard let self else { return }
            let visible = Set(self.collectionView.indexPathsForVisibleItems)
            self.cleanupUnusedImageTasks(validIndexPaths: visible)
            self.preloadVisibleImages()
        }
    }

    private func showMessage(_ message: String, showRetry: Bool) {
        messageLabel.text = message
        retryButton.isHidden = !showRetry
        statusStackView.isHidden = false
        activityIndicator.stopAnimating()
    }

    private func hideMessage() {
        statusStackView.isHidden = true
        messageLabel.text = nil
        retryButton.isHidden = true
    }

    private func startTask(_ operation: @escaping () async -> Void) {
        let task = Task {
            await operation()
        }
        tasks.append(task)
    }

    private func makeGridConfiguration(for width: CGFloat) -> GridConfiguration {
        let insets = Constants.sectionInsets
        let contentWidth = width - insets.left - insets.right
        let spacing = Constants.spacing
        let minColumns = 1
        let maxColumns = 8
        let targetWidth = (Constants.minItemWidth + Constants.maxItemWidth) / 2
        var bestColumns = 1
        var bestScore = CGFloat.greatestFiniteMagnitude
        var bestWidth = max(Constants.minItemWidth, min(contentWidth, Constants.maxItemWidth))

        for columns in minColumns...maxColumns {
            let totalSpacing = CGFloat(columns - 1) * spacing
            let candidateWidth = (contentWidth - totalSpacing) / CGFloat(columns)
            if candidateWidth < Constants.minItemWidth {
                break
            }
            let clampedWidth = min(max(candidateWidth, Constants.minItemWidth), Constants.maxItemWidth)
            let withinBounds = candidateWidth >= Constants.minItemWidth && candidateWidth <= Constants.maxItemWidth
            let penalty: CGFloat = withinBounds ? 0 : 100
            let score = abs(clampedWidth - targetWidth) + penalty
            if score < bestScore {
                bestScore = score
                bestColumns = columns
                bestWidth = clampedWidth
            }
        }

        let totalSpacing = CGFloat(bestColumns - 1) * spacing
        let adjustedWidth = min(
            (contentWidth - totalSpacing) / CGFloat(bestColumns),
            bestWidth
        )
        return GridConfiguration(
            itemWidth: adjustedWidth,
            insets: insets
        )
    }

    @objc
    private func handleRefresh() {
        startTask { [weak self] in
            await self?.viewModel.refreshSnapshot()
        }
    }

    @objc
    private func handleRetry() {
        startTask { [weak self] in
            await self?.viewModel.retry()
        }
    }

    deinit {
        tasks.forEach { $0.cancel() }
        imageTasks.values.forEach { $0.cancel() }
        stopReachabilityMonitoring()
    }
}

private extension GalleryViewController {
    enum Constants {
        static let spacing: CGFloat = 8
        static let minItemWidth: CGFloat = 100
        static let maxItemWidth: CGFloat = 120
        static let sectionInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
    }

    struct GridConfiguration {
        let itemWidth: CGFloat
        let insets: UIEdgeInsets
    }

    enum Item: Hashable {
        case image(GalleryImage)
        case placeholder(GalleryPlaceholder)
    }
}

extension GalleryViewController: UICollectionViewDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard
            let item = dataSource.itemIdentifier(for: indexPath),
            case let .image(image) = item,
            let imageCell = cell as? GalleryImageCell
        else { return }
        loadImage(for: image, at: indexPath, cell: imageCell)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didEndDisplaying cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        imageTasks[indexPath]?.cancel()
        imageTasks[indexPath] = nil
    }
}

private extension GalleryViewController {
    func loadImage(for image: GalleryImage, at indexPath: IndexPath, cell: GalleryImageCell) {
        imageTasks[indexPath]?.cancel()
        let targetSize = layout.itemSize == .zero
            ? CGSize(width: Constants.maxItemWidth, height: Constants.maxItemWidth)
            : layout.itemSize
        let scale = view.window?.screen.scale ?? UIScreen.main.scale
        let task = Task { [weak self, weak cell] in
            guard let self else { return }
            do {
                let uiImage = try await self.imageLoader.image(
                    for: image.url,
                    targetSize: targetSize,
                    scale: scale
                )
                await MainActor.run {
                    guard
                        let cell,
                        let current = self.dataSource.itemIdentifier(for: indexPath),
                        case let .image(currentImage) = current,
                        currentImage == image
                    else { return }
                    cell.configure(image: uiImage, accessibilityLabel: image.originalLine)
                }
            } catch {
                await MainActor.run {
                    guard let cell else { return }
                    cell.configure(image: nil, accessibilityLabel: image.originalLine)
                }
            }
            await MainActor.run { [weak self] in
                self?.imageTasks[indexPath] = nil
            }
        }
        imageTasks[indexPath] = task
    }

    func cleanupUnusedImageTasks(validIndexPaths: Set<IndexPath>) {
        let keysToCancel = imageTasks.keys.filter { !validIndexPaths.contains($0) }
        for key in keysToCancel {
            imageTasks[key]?.cancel()
            imageTasks[key] = nil
        }
    }

    func preloadVisibleImages() {
        collectionView.layoutIfNeeded()
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard
                let item = dataSource.itemIdentifier(for: indexPath),
                case let .image(image) = item,
                let cell = collectionView.cellForItem(at: indexPath) as? GalleryImageCell,
                imageTasks[indexPath] == nil
            else { continue }
            loadImage(for: image, at: indexPath, cell: cell)
        }
    }

    func startReachabilityMonitoring() {
        guard !isReachabilityMonitoring else { return }
        isReachabilityMonitoring = true
        reachability.startMonitoring { [weak self] status in
            guard let self else { return }
            if status == .satisfied || status == .constrained {
                self.stopReachabilityMonitoring()
                self.startTask { [weak self] in
                    await self?.viewModel.retry()
                }
            }
        }
    }

    func stopReachabilityMonitoring() {
        guard isReachabilityMonitoring else { return }
        reachability.stopMonitoring()
        isReachabilityMonitoring = false
    }
}

private final class GalleryImageCell: UICollectionViewCell {
    static let reuseIdentifier = "GalleryImageCell"

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .secondarySystemBackground
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
    }

    func configure(image: UIImage?, accessibilityLabel: String?) {
        imageView.image = image
        imageView.accessibilityLabel = accessibilityLabel
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        imageView.accessibilityLabel = nil
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class GalleryPlaceholderCell: UICollectionViewCell {
    static let reuseIdentifier = "GalleryPlaceholderCell"

    private let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = UIFont.preferredFont(forTextStyle: .caption1)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.text = "Нет превью"
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func configure(with placeholder: GalleryPlaceholder) {
        switch placeholder.reason {
        case .nonImageURL:
            label.text = "Ссылка не на изображение"
        case .invalidContent:
            label.text = "Некорректная запись"
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

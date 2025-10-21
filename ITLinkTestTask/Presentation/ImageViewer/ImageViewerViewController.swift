import UIKit

final class ImageViewerViewController: UIViewController {
    private let viewModel: ImageViewerViewModel
    private var previousNavigationBarHidden = false

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.backgroundColor = .black
        collectionView.contentInsetAdjustmentBehavior = .never
        return collectionView
    }()

    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "chevron.backward"), for: .normal)
        button.tintColor = .white
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        button.layer.cornerRadius = 22
        button.accessibilityIdentifier = Accessibility.backButton
        button.accessibilityLabel = "Назад"
        return button
    }()

    private let shareButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        button.layer.cornerRadius = 22
        button.tintColor = .white
        button.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        return button
    }()

    private let fullscreenButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        button.layer.cornerRadius = 22
        button.tintColor = .white
        button.setImage(UIImage(systemName: "arrow.up.backward.and.arrow.down.forward"), for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        return button
    }()

    private let rightStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 12
        return stack
    }()

    private let pageControl: UIPageControl = {
        let control = UIPageControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        control.hidesForSinglePage = true
        control.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.4)
        control.currentPageIndicatorTintColor = .white
        return control
    }()

    private var isChromeHidden = false {
        didSet {
            guard oldValue != isChromeHidden else { return }
            updateChrome(animated: true)
        }
    }

    init(viewModel: ImageViewerViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupBindings()
        collectionView.reloadData()
        collectionView.layoutIfNeeded()
        moveToInitialPage()
        updatePageControl()
        viewModel.start()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        previousNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(previousNavigationBarHidden, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        let size = collectionView.bounds.size
        if layout.itemSize != size {
            layout.itemSize = size
            layout.invalidateLayout()
            scrollToCurrentPage(animated: false)
        }
    }

    override var prefersStatusBarHidden: Bool {
        isChromeHidden
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        .fade
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.collectionView.collectionViewLayout.invalidateLayout()
        }, completion: { [weak self] _ in
            self?.scrollToCurrentPage(animated: false)
        })
    }

    private func setupView() {
        view.backgroundColor = .black
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(ImageViewerPageCell.self, forCellWithReuseIdentifier: ImageViewerPageCell.reuseIdentifier)
        view.addSubview(collectionView)
        view.addSubview(backButton)
        view.addSubview(rightStack)
        rightStack.addArrangedSubview(shareButton)
        rightStack.addArrangedSubview(fullscreenButton)
        view.addSubview(pageControl)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),

            rightStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            rightStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),

            shareButton.widthAnchor.constraint(equalToConstant: 44),
            shareButton.heightAnchor.constraint(equalToConstant: 44),
            fullscreenButton.widthAnchor.constraint(equalToConstant: 44),
            fullscreenButton.heightAnchor.constraint(equalToConstant: 44),

            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])

        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(handleShare), for: .touchUpInside)
        fullscreenButton.addTarget(self, action: #selector(handleFullscreen), for: .touchUpInside)
        pageControl.addTarget(self, action: #selector(handlePageControl), for: .valueChanged)
    }

    private func setupBindings() {
        viewModel.onPageStateChange = { [weak self] index, state in
            guard let self else { return }
            guard let cell = self.collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? ImageViewerPageCell else {
                return
            }
            cell.configure(with: state)
            if case .loaded = state {
                cell.resetZoom()
            }
        }

        viewModel.onCurrentIndexChange = { [weak self] index in
            guard let self else { return }
            self.pageControl.currentPage = index
        }
    }

    private func moveToInitialPage() {
        guard viewModel.totalImagesCount > 0 else { return }
        let index = min(max(0, viewModel.currentIndex), viewModel.totalImagesCount - 1)
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
    }

    private func scrollToCurrentPage(animated: Bool) {
        guard viewModel.totalImagesCount > 0 else { return }
        let indexPath = IndexPath(item: viewModel.currentIndex, section: 0)
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: animated)
    }

    private func updatePageControl() {
        pageControl.numberOfPages = viewModel.totalImagesCount
        pageControl.currentPage = viewModel.currentIndex
    }

    private func updateChrome(animated: Bool) {
        let changes = {
            self.backButton.alpha = self.isChromeHidden ? 0 : 1
            self.rightStack.alpha = self.isChromeHidden ? 0 : 1
            self.pageControl.alpha = self.isChromeHidden ? 0 : 1
            self.setNeedsStatusBarAppearanceUpdate()
        }
        if animated {
            UIView.animate(withDuration: 0.25, animations: changes)
        } else {
            changes()
        }
        let iconName = isChromeHidden
            ? "arrow.down.forward.and.arrow.up.backward"
            : "arrow.up.backward.and.arrow.down.forward"
        fullscreenButton.setImage(UIImage(systemName: iconName), for: .normal)
    }

    private func toggleChrome() {
        isChromeHidden.toggle()
    }

    @objc private func handleBack() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func handleShare() {
        guard let url = viewModel.shareURL(for: viewModel.currentIndex) else { return }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        present(activity, animated: true)
    }

    @objc private func handleFullscreen() {
        toggleChrome()
    }

    @objc private func handlePageControl() {
        let index = pageControl.currentPage
        viewModel.updateCurrentIndex(index)
        scrollToCurrentPage(animated: true)
        viewModel.loadItem(at: index)
    }
}

extension ImageViewerViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.totalImagesCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ImageViewerPageCell.reuseIdentifier,
            for: indexPath
        ) as? ImageViewerPageCell else {
            return UICollectionViewCell()
        }
        let state = viewModel.state(at: indexPath.item)
        cell.configure(with: state)
        cell.resetZoom()
        cell.onRetry = { [weak viewModel] in
            viewModel?.retryItem(at: indexPath.item)
        }
        cell.onSingleTap = { [weak self] in
            self?.toggleChrome()
        }
        cell.onDoubleTap = { [weak self] point in
            guard let self else { return }
            guard let visibleCell = self.collectionView.cellForItem(at: indexPath) as? ImageViewerPageCell else {
                return
            }
            visibleCell.zoom(at: point)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        viewModel.loadItem(at: indexPath.item)
        if let pageCell = cell as? ImageViewerPageCell {
            pageCell.prepareForDisplay()
        }
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        viewModel.cancelItem(at: indexPath.item)
        if let cell = cell as? ImageViewerPageCell {
            cell.resetZoom()
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == collectionView else { return }
        let width = scrollView.bounds.width
        guard width > 0, width.isFinite else { return }
        let rawPage = scrollView.contentOffset.x / width
        let page = Int(round(rawPage))
        guard page >= 0, page < viewModel.totalImagesCount else { return }
        if viewModel.currentIndex != page {
            viewModel.updateCurrentIndex(page)
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        collectionView.bounds.size
    }
}

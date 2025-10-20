import UIKit

extension GalleryViewController {
    func bindActions() {
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
    }

    func bindViewModel() {
        viewModel.onStateChange = { [weak self] state in
            guard let self else { return }
            apply(state: state)
        }
        apply(state: viewModel.state)
        startTask { [weak self] in
            await self?.viewModel.loadInitialSnapshot()
        }
    }

    @MainActor
    func apply(state: GalleryViewState) {
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

        let items: [SnapshotItem]
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

    func showMessage(_ message: String, showRetry: Bool) {
        messageLabel.text = message
        retryButton.isHidden = !showRetry
        statusStackView.isHidden = false
        activityIndicator.stopAnimating()
    }

    func hideMessage() {
        statusStackView.isHidden = true
        messageLabel.text = nil
        retryButton.isHidden = true
    }

    func startTask(_ operation: @escaping () async -> Void) {
        let task = Task {
            await operation()
        }
        tasks.append(task)
    }

    func startReachabilityMonitoring() {
        guard !isReachabilityMonitoring else { return }
        isReachabilityMonitoring = true
        reachability.startMonitoring { [weak self] status in
            guard let self else { return }
            if status == .satisfied || status == .constrained {
                stopReachabilityMonitoring()
                startTask { [weak self] in
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

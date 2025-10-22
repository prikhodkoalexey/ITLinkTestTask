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

        let items: [GalleryItem]
        switch state.content {
        case .empty:
            items = []
        case let .snapshot(snapshot):
            items = snapshot.items
        }
        applySnapshot(with: items)

        if let error = state.error {
            showMessage(error.message, showRetry: error.isRetryAvailable)
        } else if items.isEmpty && !state.isLoading {
            showMessage("Ничего не найдено", showRetry: false)
        } else {
            hideMessage()
        }

        if state.error != nil {
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
        lastReachabilityStatus = reachability.currentStatus
        reachability.startMonitoring { [weak self] status in
            guard let self else { return }
            let previousStatus = lastReachabilityStatus
            lastReachabilityStatus = status
            let restored = recoveredConnection(from: previousStatus, to: status)
            guard restored else { return }
            stopReachabilityMonitoring()
            startTask { [weak self] in
                await self?.viewModel.retry()
            }
        }
    }

    func stopReachabilityMonitoring() {
        guard isReachabilityMonitoring else { return }
        reachability.stopMonitoring()
        isReachabilityMonitoring = false
        lastReachabilityStatus = nil
    }

    func recoveredConnection(from previous: ReachabilityStatus?, to status: ReachabilityStatus) -> Bool {
        guard status == .satisfied || status == .constrained else { return false }
        guard let previous else {
            return false
        }
        switch previous {
        case .unsatisfied, .requiresConnection:
            return true
        case .constrained, .satisfied:
            return false
        }
    }

    @objc
    func handleRefresh() {
        startTask { [weak self] in
            await self?.viewModel.refreshSnapshot()
        }
    }

    @objc
    func handleRetry() {
        startTask { [weak self] in
            await self?.viewModel.retry()
        }
    }
}

import Foundation

final class GalleryViewModel {
    struct State: Equatable {
        var isLoading: Bool
        var isRefreshing: Bool
        var content: Content
        var error: ErrorState?

        static let initial = State(
            isLoading: false,
            isRefreshing: false,
            content: Content.empty,
            error: nil
        )
    }

    struct ErrorState: Equatable {
        let message: String
        let isRetryAvailable: Bool
    }

    enum Content: Equatable {
        case empty
        case snapshot(GallerySnapshot)
    }

    typealias SnapshotLoader = () async throws -> GallerySnapshot

    private let loadSnapshotHandler: SnapshotLoader
    private let refreshSnapshotHandler: SnapshotLoader

    private var stateStorage: State = .initial

    var state: State { stateStorage }

    var onStateChange: ((State) -> Void)? {
        didSet {
            guard let observer = onStateChange else { return }
            observer(stateStorage)
        }
    }

    init(
        loadSnapshot: @escaping SnapshotLoader,
        refreshSnapshot: @escaping SnapshotLoader
    ) {
        self.loadSnapshotHandler = loadSnapshot
        self.refreshSnapshotHandler = refreshSnapshot
    }

    func loadInitialSnapshot() async {
        let shouldStart = await MainActor.run { () -> Bool in
            guard !stateStorage.isLoading else { return false }
            stateStorage = State(
                isLoading: true,
                isRefreshing: false,
                content: Content.empty,
                error: nil
            )
            onStateChange?(stateStorage)
            return true
        }
        guard shouldStart else { return }
        await performLoad(
            using: loadSnapshotHandler,
            fallbackContent: Content.empty,
            failureMessage: "Не удалось загрузить галерею. Попробуйте ещё раз."
        )
    }

    func refreshSnapshot() async {
        let currentState = await MainActor.run { stateStorage }
        guard !currentState.isRefreshing else { return }
        switch currentState.content {
        case .empty:
            await loadInitialSnapshot()
        case .snapshot:
            await MainActor.run {
                var nextState = currentState
                nextState.isRefreshing = true
                nextState.error = nil
                stateStorage = nextState
                onStateChange?(nextState)
            }
            await performLoad(
                using: refreshSnapshotHandler,
                fallbackContent: currentState.content,
                failureMessage: "Не удалось обновить галерею. Попробуйте ещё раз."
            )
        }
    }

    func retry() async {
        let currentContent = await MainActor.run { stateStorage.content }
        switch currentContent {
        case .empty:
            await loadInitialSnapshot()
        case .snapshot:
            await refreshSnapshot()
        }
    }

    private func performLoad(
        using loader: @escaping SnapshotLoader,
        fallbackContent: Content,
        failureMessage: String
    ) async {
        do {
            let snapshot = try await loader()
            await MainActor.run {
                stateStorage = State(
                    isLoading: false,
                    isRefreshing: false,
                    content: .snapshot(snapshot),
                    error: nil
                )
                onStateChange?(stateStorage)
            }
        } catch is CancellationError {
            await MainActor.run {
                stateStorage = State(
                    isLoading: false,
                    isRefreshing: false,
                    content: fallbackContent,
                    error: nil
                )
                onStateChange?(stateStorage)
            }
        } catch {
            await MainActor.run {
                stateStorage = State(
                    isLoading: false,
                    isRefreshing: false,
                    content: fallbackContent,
                    error: ErrorState(
                        message: failureMessage,
                        isRetryAvailable: true
                    )
                )
                onStateChange?(stateStorage)
            }
        }
    }

    deinit {
        onStateChange = nil
    }
}

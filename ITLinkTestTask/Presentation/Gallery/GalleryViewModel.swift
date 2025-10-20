import Foundation

final class GalleryViewModel {
    typealias SnapshotLoader = () async throws -> GallerySnapshot

    private let loadSnapshotHandler: SnapshotLoader
    private let refreshSnapshotHandler: SnapshotLoader

    private var stateStorage: GalleryViewState = .initial

    var state: GalleryViewState { stateStorage }

    var onStateChange: ((GalleryViewState) -> Void)? {
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
        let shouldStart = await MainActor.run { startInitialLoad() }
        guard shouldStart else { return }
        await performLoad(
            using: loadSnapshotHandler,
            fallbackContent: .empty,
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
            await MainActor.run { beginRefresh(from: currentState) }
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
        fallbackContent: GalleryViewContent,
        failureMessage: String
    ) async {
        do {
            let snapshot = try await loader()
            await MainActor.run {
                concludeLoad(content: .snapshot(snapshot))
            }
        } catch is CancellationError {
            await MainActor.run {
                concludeLoad(content: fallbackContent)
            }
        } catch {
            await MainActor.run {
                concludeLoad(
                    content: fallbackContent,
                    errorMessage: failureMessage
                )
            }
        }
    }

    deinit {
        onStateChange = nil
    }

    @MainActor
    private func startInitialLoad() -> Bool {
        guard !stateStorage.isLoading else { return false }
        emit(
            GalleryViewState(
                isLoading: true,
                isRefreshing: false,
                content: .empty,
                error: nil
            )
        )
        return true
    }

    @MainActor
    private func beginRefresh(from state: GalleryViewState) {
        var next = state
        next.isRefreshing = true
        next.error = nil
        emit(next)
    }

    @MainActor
    private func concludeLoad(
        content: GalleryViewContent,
        errorMessage: String? = nil
    ) {
        let errorState = errorMessage.map {
            GalleryViewError(message: $0, isRetryAvailable: true)
        }
        emit(
            GalleryViewState(
                isLoading: false,
                isRefreshing: false,
                content: content,
                error: errorState
            )
        )
    }

    @MainActor
    private func emit(_ state: GalleryViewState) {
        stateStorage = state
        onStateChange?(state)
    }
}

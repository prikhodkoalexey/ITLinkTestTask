import XCTest
@testable import ITLinkTestTask

@MainActor
final class GalleryViewModelTests: XCTestCase {
    func testInitialStateIsIdle() {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.state, .initial)
    }

    func testObserverReceivesInitialStateImmediately() {
        let viewModel = makeViewModel()
        var observedStates: [GalleryViewState] = []

        viewModel.onStateChange = { [weak viewModel] state in
            _ = viewModel
            observedStates.append(state)
        }

        XCTAssertEqual(observedStates, [.initial])
    }

    func testLoadInitialSnapshotEmitsLoadingAndContentState() async {
        let snapshot = makeSnapshot(identifier: "initial")
        let viewModel = makeViewModel(loadResults: [.success(snapshot)])
        var observedStates: [GalleryViewState] = []
        viewModel.onStateChange = { [weak viewModel] state in
            _ = viewModel
            observedStates.append(state)
        }

        await viewModel.loadInitialSnapshot()

        XCTAssertEqual(
            observedStates,
            [
                .initial,
                GalleryViewState(
                    isLoading: true,
                    isRefreshing: false,
                    content: .empty,
                    error: nil
                ),
                GalleryViewState(
                    isLoading: false,
                    isRefreshing: false,
                    content: .snapshot(snapshot),
                    error: nil
                )
            ]
        )
    }

    func testLoadInitialSnapshotFailureProducesError() async {
        let viewModel = makeViewModel(loadResults: [.failure(TestError())])

        await viewModel.loadInitialSnapshot()

        XCTAssertEqual(
            viewModel.state,
            GalleryViewState(
                isLoading: false,
                isRefreshing: false,
                content: .empty,
                error: GalleryViewError(
                    message: "Не удалось загрузить галерею. Попробуйте ещё раз.",
                    isRetryAvailable: true
                )
            )
        )
    }

    func testRefreshSnapshotUsesRefreshLoaderWhenContentAvailable() async {
        let initial = makeSnapshot(identifier: "initial")
        let refreshed = makeSnapshot(identifier: "refreshed")
        let viewModel = makeViewModel(
            loadResults: [.success(initial)],
            refreshResults: [.success(refreshed)]
        )

        await viewModel.loadInitialSnapshot()
        await viewModel.refreshSnapshot()

        XCTAssertEqual(
            viewModel.state,
            GalleryViewState(
                isLoading: false,
                isRefreshing: false,
                content: .snapshot(refreshed),
                error: nil
            )
        )
    }

    func testRefreshSnapshotKeepsPreviousContentOnFailure() async {
        let initial = makeSnapshot(identifier: "initial")
        let viewModel = makeViewModel(
            loadResults: [.success(initial)],
            refreshResults: [.failure(TestError())]
        )

        await viewModel.loadInitialSnapshot()
        await viewModel.refreshSnapshot()

        XCTAssertEqual(
            viewModel.state,
            GalleryViewState(
                isLoading: false,
                isRefreshing: false,
                content: .snapshot(initial),
                error: GalleryViewError(
                    message: "Не удалось обновить галерею. Попробуйте ещё раз.",
                    isRetryAvailable: true
                )
            )
        )
    }

    func testRefreshSnapshotFallsBackToInitialLoadWhenEmpty() async {
        let snapshot = makeSnapshot(identifier: "loaded-after-refresh")
        let viewModel = makeViewModel(
            loadResults: [.failure(TestError()), .success(snapshot)]
        )

        await viewModel.loadInitialSnapshot()
        await viewModel.refreshSnapshot()

        XCTAssertEqual(
            viewModel.state,
            GalleryViewState(
                isLoading: false,
                isRefreshing: false,
                content: .snapshot(snapshot),
                error: nil
            )
        )
    }

    func testRetryTriggersRefreshWhenContentAvailable() async {
        let initial = makeSnapshot(identifier: "initial")
        let refreshed = makeSnapshot(identifier: "refreshed")
        let viewModel = makeViewModel(
            loadResults: [.success(initial)],
            refreshResults: [.failure(TestError()), .success(refreshed)]
        )

        await viewModel.loadInitialSnapshot()
        await viewModel.refreshSnapshot()
        await viewModel.retry()

        XCTAssertEqual(
            viewModel.state,
            GalleryViewState(
                isLoading: false,
                isRefreshing: false,
                content: .snapshot(refreshed),
                error: nil
            )
        )
    }

    func testRetryTriggersInitialLoadWhenContentMissing() async {
        let snapshot = makeSnapshot(identifier: "retried")
        let viewModel = makeViewModel(
            loadResults: [.failure(TestError()), .success(snapshot)]
        )

        await viewModel.loadInitialSnapshot()
        await viewModel.retry()

        XCTAssertEqual(
            viewModel.state,
            GalleryViewState(
                isLoading: false,
                isRefreshing: false,
                content: .snapshot(snapshot),
                error: nil
            )
        )
    }

    func testRefreshSetsRefreshingFlagDuringOperation() async {
        let initial = makeSnapshot(identifier: "initial")
        let refreshed = makeSnapshot(identifier: "refreshed")
        let refreshStore = SnapshotResultStore(results: [.success(refreshed)])
        let viewModel = GalleryViewModel(
            loadSnapshot: SnapshotResultStore(results: [.success(initial)]).next,
            refreshSnapshot: {
                try await Task.sleep(nanoseconds: 50_000_000)
                return try await refreshStore.next()
            }
        )
        await viewModel.loadInitialSnapshot()

        let expectation = XCTestExpectation(description: "refresh flag toggled")
        viewModel.onStateChange = { [weak viewModel] state in
            _ = viewModel
            if state.isRefreshing {
                expectation.fulfill()
            }
        }

        await viewModel.refreshSnapshot()
        await fulfillment(of: [expectation], timeout: 0.5)
        XCTAssertFalse(viewModel.state.isRefreshing)
    }

    // MARK: - Helpers

    private func makeViewModel(
        loadResults: [Result<GallerySnapshot, Error>]? = nil,
        refreshResults: [Result<GallerySnapshot, Error>]? = nil
    ) -> GalleryViewModel {
        let loadQueue = loadResults ?? [.success(makeSnapshot(identifier: "default-load"))]
        let refreshQueue = refreshResults ?? [.success(makeSnapshot(identifier: "default-refresh"))]
        let loadStore = SnapshotResultStore(results: loadQueue)
        let refreshStore = SnapshotResultStore(results: refreshQueue)
        return GalleryViewModel(
            loadSnapshot: loadStore.next,
            refreshSnapshot: refreshStore.next
        )
    }

    private func makeSnapshot(identifier: String) -> GallerySnapshot {
        let url = URL(string: "https://example.com/\(identifier).jpg")!
        let image = GalleryImage(
            url: url,
            originalLine: url.absoluteString,
            lineNumber: 1
        )
        return GallerySnapshot(
            sourceURL: URL(string: "https://example.com/source.txt")!,
            fetchedAt: Date(timeIntervalSince1970: 100),
            items: [.image(image)]
        )
    }

    private struct TestError: Error {}
}

private final class SnapshotResultStore {
    private var results: [Result<GallerySnapshot, Error>]

    init(results: [Result<GallerySnapshot, Error>]) {
        self.results = results
    }

    func next() async throws -> GallerySnapshot {
        guard !results.isEmpty else {
            fatalError("No more results queued")
        }
        let result = results.removeFirst()
        return try result.get()
    }
}

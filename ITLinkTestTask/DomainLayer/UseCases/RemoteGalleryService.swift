import Foundation

protocol RemoteGalleryService {
    func refreshLinks() async throws -> LinksFileSnapshot
    func metadata(for url: URL) async throws -> ImageMetadata
}

final class DefaultRemoteGalleryService: RemoteGalleryService {
    private let linksDataSource: LinksFileRemoteDataSource
    private let metadataProbe: ImageMetadataProbe
    private let reachability: ReachabilityService
    private let retryPolicy: RetryPolicy

    init(
        linksDataSource: LinksFileRemoteDataSource,
        metadataProbe: ImageMetadataProbe,
        reachability: ReachabilityService,
        retryPolicy: RetryPolicy = .default
    ) {
        self.linksDataSource = linksDataSource
        self.metadataProbe = metadataProbe
        self.reachability = reachability
        self.retryPolicy = retryPolicy
    }

    func refreshLinks() async throws -> LinksFileSnapshot {
        try await performWithRetry { [linksDataSource] in
            try await linksDataSource.fetchLinks()
        }
    }

    func metadata(for url: URL) async throws -> ImageMetadata {
        try await performWithRetry { [metadataProbe] in
            try await metadataProbe.metadata(for: url)
        }
    }

    private func performWithRetry<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var attempt = 0
        var lastError: Error?

        while attempt <= retryPolicy.maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                attempt += 1

                if attempt > retryPolicy.maxAttempts {
                    break
                }

                try await waitForRetry(after: retryPolicy.delay(for: attempt))
            }
        }

        throw lastError ?? NetworkingError.unknown
    }

    private func waitForRetry(after delay: TimeInterval) async throws {
        if isReachable(reachability.currentStatus) {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return
        }

        let lock = NSLock()
        var continuation: CheckedContinuation<Void, Error>?

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (inner: CheckedContinuation<Void, Error>) in
                lock.lock()
                continuation = inner
                lock.unlock()

                reachability.startMonitoring { [weak self] status in
                    guard let self, self.isReachable(status) else { return }
                    self.reachability.stopMonitoring()

                    lock.lock()
                    guard let pending = continuation else {
                        lock.unlock()
                        return
                    }
                    continuation = nil
                    lock.unlock()
                    pending.resume(returning: ())
                }
            }
        } onCancel: {
            reachability.stopMonitoring()
            lock.lock()
            let pending = continuation
            continuation = nil
            lock.unlock()
            pending?.resume(throwing: CancellationError())
        }

        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }

    private func isReachable(_ status: ReachabilityStatus) -> Bool {
        switch status {
        case .satisfied, .constrained:
            return true
        case .unsatisfied, .requiresConnection:
            return false
        }
    }
}

struct RetryPolicy {
    let maxAttempts: Int
    let baseDelay: TimeInterval

    func delay(for attempt: Int) -> TimeInterval {
        baseDelay * pow(2, Double(attempt - 1))
    }

    static let `default` = RetryPolicy(maxAttempts: 2, baseDelay: 1.0)
}

extension NetworkingError {
    static let unknown = NetworkingError.invalidURL("unknown")
}

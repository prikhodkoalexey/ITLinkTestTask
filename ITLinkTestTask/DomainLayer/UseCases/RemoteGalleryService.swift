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
        if reachability.currentStatus == .satisfied {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return
        }

        try await withCheckedThrowingContinuation { continuation in
            reachability.startMonitoring { status in
                if status == .satisfied || status == .constrained {
                    self.reachability.stopMonitoring()
                    continuation.resume()
                }
            }
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

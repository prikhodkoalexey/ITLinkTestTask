import Network
import XCTest
@testable import ITLinkTestTask

final class DefaultReachabilityServiceTests: XCTestCase {}

private final class ReachabilityMonitorStub: ReachabilityMonitoring {
    var pathUpdateHandler: ((NWPath) -> Void)?
    private(set) var startCallCount = 0
    private(set) var cancelCallCount = 0

    func start(queue: DispatchQueue) {
        startCallCount += 1
    }

    func cancel() {
        cancelCallCount += 1
    }
}

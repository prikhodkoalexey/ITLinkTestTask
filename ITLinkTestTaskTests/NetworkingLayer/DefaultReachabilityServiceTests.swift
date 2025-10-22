import Network
import XCTest
@testable import ITLinkTestTask

final class DefaultReachabilityServiceTests: XCTestCase {
    func testStartTwiceWithoutStopReusesMonitor() {
        let stub = ReachabilityMonitorStub()
        let service = DefaultReachabilityService(
            monitorFactory: { stub },
            queue: DispatchQueue(label: "reachability.test.queue")
        )

        service.startMonitoring { _ in }
        service.startMonitoring { _ in }

        XCTAssertEqual(stub.startCallCount, 1)
        XCTAssertEqual(stub.cancelCallCount, 0)
    }
}

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

import Network
import XCTest
@testable import ITLinkTestTask

final class DefaultReachabilityServiceTests: XCTestCase {
    func testStartAfterStopCreatesNewMonitor() {
        var createdMonitors: [ReachabilityMonitorStub] = []
        let service = DefaultReachabilityService(
            monitorFactory: {
                let stub = ReachabilityMonitorStub()
                createdMonitors.append(stub)
                return stub
            },
            queue: DispatchQueue(label: "reachability.test.queue")
        )

        service.startMonitoring { _ in }

        XCTAssertEqual(createdMonitors.count, 1)
        XCTAssertEqual(createdMonitors[0].startCallCount, 1)

        service.stopMonitoring()

        XCTAssertEqual(createdMonitors[0].cancelCallCount, 1)

        service.startMonitoring { _ in }

        XCTAssertEqual(createdMonitors.count, 2)
        XCTAssertEqual(createdMonitors[1].startCallCount, 1)
    }

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

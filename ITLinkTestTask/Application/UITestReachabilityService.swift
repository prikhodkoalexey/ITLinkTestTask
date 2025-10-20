import Foundation

final class UITestReachabilityService: ReachabilityService {
    private var handler: ((ReachabilityStatus) -> Void)?

    var currentStatus: ReachabilityStatus {
        .unsatisfied
    }

    func startMonitoring(changeHandler: @escaping (ReachabilityStatus) -> Void) {
        handler = changeHandler
    }

    func stopMonitoring() {
        handler = nil
    }
}

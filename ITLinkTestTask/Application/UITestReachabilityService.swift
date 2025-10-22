import Foundation

final class UITestReachabilityService: ReachabilityService {
    private var handler: ((ReachabilityStatus) -> Void)?
    private let autoTrigger: Bool
    private let triggerDelay: TimeInterval
    private let queue: DispatchQueue
    private var status: ReachabilityStatus

    init(
        autoTrigger: Bool = ProcessInfo.processInfo.environment["UITEST_REACHABILITY_AUTO"] == "1",
        triggerDelay: TimeInterval = 1.0,
        queue: DispatchQueue = .global(qos: .utility),
        initialStatus: ReachabilityStatus = .unsatisfied
    ) {
        self.autoTrigger = autoTrigger
        self.triggerDelay = triggerDelay
        self.queue = queue
        self.status = initialStatus
    }

    var currentStatus: ReachabilityStatus {
        status
    }

    func startMonitoring(changeHandler: @escaping (ReachabilityStatus) -> Void) {
        handler = changeHandler
        if autoTrigger {
            queue.asyncAfter(deadline: .now() + triggerDelay) { [weak self] in
                self?.notify(status: .satisfied)
            }
        }
    }

    func stopMonitoring() {
        handler = nil
    }

    private func notify(status: ReachabilityStatus) {
        self.status = status
        handler?(status)
    }
}

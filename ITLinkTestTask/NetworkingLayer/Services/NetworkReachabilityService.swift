import Foundation
import Network

enum ReachabilityStatus: Equatable {
    case satisfied
    case unsatisfied
    case requiresConnection
    case constrained
}

protocol ReachabilityService {
    var currentStatus: ReachabilityStatus { get }
    func startMonitoring(changeHandler: @escaping (ReachabilityStatus) -> Void)
    func stopMonitoring()
}

final class DefaultReachabilityService: ReachabilityService {
    private let monitor: NWPathMonitor
    private let queue: DispatchQueue
    private var handler: ((ReachabilityStatus) -> Void)?

    init(monitor: NWPathMonitor = NWPathMonitor(), queue: DispatchQueue = .global(qos: .background)) {
        self.monitor = monitor
        self.queue = queue
    }

    private(set) var currentStatus: ReachabilityStatus = .unsatisfied

    func startMonitoring(changeHandler: @escaping (ReachabilityStatus) -> Void) {
        handler = changeHandler
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let status = self.map(path: path)
            self.currentStatus = status
            changeHandler(status)
        }
        monitor.start(queue: queue)
    }

    func stopMonitoring() {
        monitor.cancel()
        handler = nil
    }

    private func map(path: NWPath) -> ReachabilityStatus {
        if path.status == .satisfied {
            if path.isExpensive || path.isConstrained {
                return .constrained
            }
            return .satisfied
        }
        if path.status == .requiresConnection {
            return .requiresConnection
        }
        return .unsatisfied
    }
}

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

protocol ReachabilityMonitoring: AnyObject {
    var pathUpdateHandler: ((NWPath) -> Void)? { get set }
    func start(queue: DispatchQueue)
    func cancel()
}

extension NWPathMonitor: ReachabilityMonitoring {}

final class DefaultReachabilityService: ReachabilityService {
    private let monitorFactory: () -> ReachabilityMonitoring
    private let queue: DispatchQueue
    private var handler: ((ReachabilityStatus) -> Void)?
    private var monitor: ReachabilityMonitoring?
    private var isMonitoring = false

    init(
        monitorFactory: @escaping () -> ReachabilityMonitoring = { NWPathMonitor() },
        queue: DispatchQueue = .global(qos: .background)
    ) {
        self.monitorFactory = monitorFactory
        self.queue = queue
    }

    private(set) var currentStatus: ReachabilityStatus = .unsatisfied

    func startMonitoring(changeHandler: @escaping (ReachabilityStatus) -> Void) {
        handler = changeHandler
        let activeMonitor: ReachabilityMonitoring
        if let existing = monitor {
            activeMonitor = existing
        } else {
            let created = monitorFactory()
            monitor = created
            activeMonitor = created
        }
        activeMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let status = self.map(path: path)
            self.currentStatus = status
            self.handler?(status)
        }
        if !isMonitoring {
            activeMonitor.start(queue: queue)
            isMonitoring = true
        }
    }

    func stopMonitoring() {
        monitor?.cancel()
        monitor = nil
        handler = nil
        isMonitoring = false
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

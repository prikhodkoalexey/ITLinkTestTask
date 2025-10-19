import Dispatch
import Foundation

final class DefaultDiskStore: DiskStore, @unchecked Sendable {
    private let fileManager: FileManager
    private let baseURL: URL
    private let queue: DispatchQueue

    init(
        fileManager: FileManager = FileManager(),
        baseURL: URL? = nil,
        queue: DispatchQueue = DispatchQueue(label: "com.itlink.diskstore", qos: .utility)
    ) throws {
        self.fileManager = fileManager
        self.queue = queue
        if let baseURL {
            self.baseURL = baseURL
        } else {
            guard let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                throw DiskStoreError.directoryCreationFailed(URL(fileURLWithPath: NSTemporaryDirectory()))
            }
            self.baseURL = cachesDirectory.appendingPathComponent("Storage", isDirectory: true)
        }
        try ensureDirectoriesExistLocked()
    }

    func directoryURL(for namespace: DiskStoreNamespace) throws -> URL {
        try queue.sync {
            try directoryURLLocked(for: namespace)
        }
    }

    func fileURL(in namespace: DiskStoreNamespace, fileName: String) throws -> URL {
        try queue.sync {
            let directory = try directoryURLLocked(for: namespace)
            return directory.appendingPathComponent(fileName, isDirectory: false)
        }
    }

    private func directoryURLLocked(for namespace: DiskStoreNamespace) throws -> URL {
        let namespaceURL = baseURL.appendingPathComponent(namespace.rawValue, isDirectory: true)
        try ensureDirectoryLocked(at: namespaceURL)
        return namespaceURL
    }

    private func ensureDirectoriesExistLocked() throws {
        for namespace in DiskStoreNamespace.allCases {
            let url = baseURL.appendingPathComponent(namespace.rawValue, isDirectory: true)
            try ensureDirectoryLocked(at: url)
        }
    }

    private func ensureDirectoryLocked(at url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            return
        }
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw DiskStoreError.directoryCreationFailed(url)
        }
    }
}

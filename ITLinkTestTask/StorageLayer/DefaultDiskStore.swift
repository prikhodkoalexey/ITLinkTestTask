import Foundation

final class DefaultDiskStore: DiskStore {
    private let fileManager: FileManager
    private let baseURL: URL

    init(
        fileManager: FileManager = .default,
        baseURL: URL? = nil
    ) throws {
        self.fileManager = fileManager
        if let baseURL {
            self.baseURL = baseURL
        } else {
            guard let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                throw DiskStoreError.directoryCreationFailed(URL(fileURLWithPath: NSTemporaryDirectory()))
            }
            self.baseURL = cachesDirectory.appendingPathComponent("Storage", isDirectory: true)
        }
        try ensureDirectoriesExist()
    }

    func directoryURL(for namespace: DiskStoreNamespace) throws -> URL {
        let namespaceURL = baseURL.appendingPathComponent(namespace.rawValue, isDirectory: true)
        try ensureDirectory(at: namespaceURL)
        return namespaceURL
    }

    func fileURL(in namespace: DiskStoreNamespace, fileName: String) throws -> URL {
        let directory = try directoryURL(for: namespace)
        return directory.appendingPathComponent(fileName, isDirectory: false)
    }

    private func ensureDirectoriesExist() throws {
        for namespace in DiskStoreNamespace.allCases {
            let url = baseURL.appendingPathComponent(namespace.rawValue, isDirectory: true)
            try ensureDirectory(at: url)
        }
    }

    private func ensureDirectory(at url: URL) throws {
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

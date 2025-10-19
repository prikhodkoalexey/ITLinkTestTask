import Foundation

enum DiskStoreNamespace: String, CaseIterable, Sendable {
    case links
    case thumbnails
    case originals
}

enum DiskStoreError: Error, Sendable {
    case directoryCreationFailed(URL)
}

protocol DiskStore: Sendable {
    func directoryURL(for namespace: DiskStoreNamespace) throws -> URL
    func fileURL(in namespace: DiskStoreNamespace, fileName: String) throws -> URL
}

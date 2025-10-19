import Foundation

enum DiskStoreNamespace: String, CaseIterable {
    case links
    case thumbnails
    case originals
}

enum DiskStoreError: Error {
    case directoryCreationFailed(URL)
}

protocol DiskStore {
    func directoryURL(for namespace: DiskStoreNamespace) throws -> URL
    func fileURL(in namespace: DiskStoreNamespace, fileName: String) throws -> URL
}

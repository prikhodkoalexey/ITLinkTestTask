import Foundation

enum ImageDataVariant {
    case thumbnail
    case original

    var namespace: DiskStoreNamespace {
        switch self {
        case .thumbnail:
            return .thumbnails
        case .original:
            return .originals
        }
    }
}

struct ImageDataCacheConfiguration {
    let thumbnailLimit: Int?
    let originalLimit: Int?

    static let `default` = ImageDataCacheConfiguration(
        thumbnailLimit: 20 * 1024 * 1024,
        originalLimit: 200 * 1024 * 1024
    )
}

protocol ImageDataCaching {
    func data(for url: URL, variant: ImageDataVariant) async throws -> Data?
    func store(_ data: Data, for url: URL, variant: ImageDataVariant) async throws
    func remove(for url: URL, variant: ImageDataVariant) async throws
    func clear(variant: ImageDataVariant) async throws
}

actor DefaultImageDataCache: ImageDataCaching {
    private let store: DiskStore
    private let hasher: FileNameHashing
    private let fileManager: FileManager
    private let configuration: ImageDataCacheConfiguration

    init(
        store: DiskStore,
        hasher: FileNameHashing,
        fileManager: FileManager = .default,
        configuration: ImageDataCacheConfiguration = .default
    ) {
        self.store = store
        self.hasher = hasher
        self.fileManager = fileManager
        self.configuration = configuration
    }

    func data(for url: URL, variant: ImageDataVariant) async throws -> Data? {
        let fileURL = try fileURL(for: url, variant: variant)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        try updateAccessDate(for: fileURL)
        return data
    }

    func store(_ data: Data, for url: URL, variant: ImageDataVariant) async throws {
        let fileURL = try fileURL(for: url, variant: variant)
        try data.write(to: fileURL, options: [.atomic])
        try updateAccessDate(for: fileURL)
        try trimIfNeeded(for: variant)
    }

    func remove(for url: URL, variant: ImageDataVariant) async throws {
        let fileURL = try fileURL(for: url, variant: variant)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    func clear(variant: ImageDataVariant) async throws {
        let directory = try store.directoryURL(for: variant.namespace)
        let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for file in contents {
            try fileManager.removeItem(at: file)
        }
    }

    private func fileURL(for url: URL, variant: ImageDataVariant) throws -> URL {
        let ext = url.pathExtension
        let fileName = hasher.makeFileName(for: url.absoluteString, fileExtension: ext.isEmpty ? nil : ext)
        return try store.fileURL(in: variant.namespace, fileName: fileName)
    }

    private func limit(for variant: ImageDataVariant) -> Int? {
        switch variant {
        case .thumbnail:
            return configuration.thumbnailLimit
        case .original:
            return configuration.originalLimit
        }
    }

    private func trimIfNeeded(for variant: ImageDataVariant) throws {
        guard let limit = limit(for: variant) else { return }
        let directory = try store.directoryURL(for: variant.namespace)
        var resourceKeys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
        let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        )
        guard let urls = enumerator?.compactMap({ $0 as? URL }) else { return }
        var entries: [FileEntry] = []
        var totalSize = 0
        for fileURL in urls {
            let values = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            guard values.isRegularFile == true else { continue }
            let size = values.fileSize ?? 0
            let date = values.contentModificationDate ?? Date.distantPast
            entries.append(FileEntry(url: fileURL, size: size, date: date))
            totalSize += size
        }
        guard totalSize > limit else { return }
        let sorted = entries.sorted { $0.date < $1.date }
        var currentSize = totalSize
        for entry in sorted {
            try fileManager.removeItem(at: entry.url)
            currentSize -= entry.size
            if currentSize <= limit {
                break
            }
        }
    }

    private func updateAccessDate(for url: URL) throws {
        try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
    }
}

private struct FileEntry {
    let url: URL
    let size: Int
    let date: Date
}

import Foundation

struct MemoryImageCacheConfiguration: Equatable {
    let thumbnailCostLimit: Int?
    let originalCostLimit: Int?

    static let `default` = MemoryImageCacheConfiguration(
        thumbnailCostLimit: 10 * 1024 * 1024,
        originalCostLimit: 80 * 1024 * 1024
    )
}

protocol MemoryImageCaching: Sendable {
    func data(for url: URL, variant: ImageDataVariant) -> Data?
    func store(_ data: Data, for url: URL, variant: ImageDataVariant)
    func remove(for url: URL, variant: ImageDataVariant)
    func clear()
}

final class DefaultMemoryImageCache: MemoryImageCaching, @unchecked Sendable {
    private let thumbnailCache = NSCache<NSString, NSData>()
    private let originalCache = NSCache<NSString, NSData>()

    init(configuration: MemoryImageCacheConfiguration = .default) {
        if let limit = configuration.thumbnailCostLimit {
            thumbnailCache.totalCostLimit = limit
        }
        if let limit = configuration.originalCostLimit {
            originalCache.totalCostLimit = limit
        }
    }

    func data(for url: URL, variant: ImageDataVariant) -> Data? {
        cache(for: variant).object(forKey: key(for: url)) as Data?
    }

    func store(_ data: Data, for url: URL, variant: ImageDataVariant) {
        cache(for: variant).setObject(data as NSData, forKey: key(for: url), cost: data.count)
    }

    func remove(for url: URL, variant: ImageDataVariant) {
        cache(for: variant).removeObject(forKey: key(for: url))
    }

    func clear() {
        thumbnailCache.removeAllObjects()
        originalCache.removeAllObjects()
    }

    private func cache(for variant: ImageDataVariant) -> NSCache<NSString, NSData> {
        switch variant {
        case .thumbnail:
            return thumbnailCache
        case .original:
            return originalCache
        }
    }

    private func key(for url: URL) -> NSString {
        NSString(string: url.absoluteString)
    }
}

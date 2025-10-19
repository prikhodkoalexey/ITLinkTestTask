import Foundation

struct StorageAssembly {
    let diskStore: DiskStore
    let fileNameHasher: FileNameHashing
    let linksCache: any LinksFileCaching
    let imageCache: any ImageDataCaching

    init(
        diskStore: DiskStore,
        fileNameHasher: FileNameHashing = SHA256FileNameHasher()
    ) {
        self.diskStore = diskStore
        self.fileNameHasher = fileNameHasher
        linksCache = DefaultLinksFileCache(store: diskStore)
        imageCache = DefaultImageDataCache(
            store: diskStore,
            hasher: fileNameHasher
        )
    }

    static func makeDefault() throws -> StorageAssembly {
        let store = try DefaultDiskStore()
        let hasher = SHA256FileNameHasher()
        return StorageAssembly(diskStore: store, fileNameHasher: hasher)
    }
}

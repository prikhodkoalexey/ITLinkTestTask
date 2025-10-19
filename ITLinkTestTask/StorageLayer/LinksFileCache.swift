import Foundation

protocol LinksFileCaching {
    func loadSnapshot() async throws -> LinksFileSnapshot?
    func saveSnapshot(_ snapshot: LinksFileSnapshot) async throws
    func clear() async throws
}

actor DefaultLinksFileCache: LinksFileCaching {
    private let store: DiskStore
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileName = "links.json"

    init(
        store: DiskStore,
        fileManager: FileManager = FileManager(),
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.store = store
        self.fileManager = fileManager
        self.encoder = encoder
        self.decoder = decoder
    }

    func loadSnapshot() async throws -> LinksFileSnapshot? {
        let url = try store.fileURL(in: .links, fileName: fileName)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LinksFileSnapshot.self, from: data)
    }

    func saveSnapshot(_ snapshot: LinksFileSnapshot) async throws {
        let url = try store.fileURL(in: .links, fileName: fileName)
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: [.atomic])
    }

    func clear() async throws {
        let url = try store.fileURL(in: .links, fileName: fileName)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}

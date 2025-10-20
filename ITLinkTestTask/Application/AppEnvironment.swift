import Foundation

struct AppEnvironment {
    let networking: NetworkingAssembly
    let storage: StorageAssembly
    let gallery: GalleryDomainAssembly

    static func makeDefault() -> AppEnvironment {
        do {
            let storage = try StorageAssembly.makeDefault()
            guard let endpoint = URL(string: "https://it-link.ru/test/images.txt") else {
                fatalError("Failed to create links endpoint URL")
            }
            let networking = NetworkingAssembly(linksEndpoint: endpoint)
            let gallery = GalleryDomainAssembly(networking: networking, storage: storage)
            return AppEnvironment(networking: networking, storage: storage, gallery: gallery)
        } catch {
            fatalError("Failed to create storage assembly: \(error)")
        }
    }
}

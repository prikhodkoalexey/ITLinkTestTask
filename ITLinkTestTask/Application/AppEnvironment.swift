import Foundation

struct AppEnvironment {
    let networking: NetworkingAssembly
    let storage: StorageAssembly
    let gallery: GalleryDomainAssembly
    let presentation: PresentationAssembly

    static func makeDefault() -> AppEnvironment {
        do {
            let storage = try StorageAssembly.makeDefault()
            guard let endpoint = URL(string: "https://it-link.ru/test/images.txt") else {
                fatalError("Failed to create links endpoint URL")
            }
            let networking = NetworkingAssembly(linksEndpoint: endpoint)
            let gallery = GalleryDomainAssembly(networking: networking, storage: storage)
            let presentation = PresentationAssembly(domain: gallery)
            return AppEnvironment(
                networking: networking,
                storage: storage,
                gallery: gallery,
                presentation: presentation
            )
        } catch {
            fatalError("Failed to create storage assembly: \(error)")
        }
    }
}

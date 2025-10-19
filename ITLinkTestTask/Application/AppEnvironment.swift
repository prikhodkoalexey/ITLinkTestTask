import Foundation

struct AppEnvironment {
    let networking: NetworkingAssembly
    let storage: StorageAssembly

    static func makeDefault() -> AppEnvironment {
        do {
            let storage = try StorageAssembly.makeDefault()
            guard let endpoint = URL(string: "https://it-link.ru/test/images.txt") else {
                fatalError("Failed to create links endpoint URL")
            }
            let networking = NetworkingAssembly(linksEndpoint: endpoint)
            return AppEnvironment(networking: networking, storage: storage)
        } catch {
            fatalError("Failed to create storage assembly: \(error)")
        }
    }
}

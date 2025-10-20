import Foundation

struct AppEnvironment {
    let networking: NetworkingAssembly
    let storage: StorageAssembly
    let gallery: GalleryDomainAssembly
    let presentation: PresentationAssembly

    static func makeDefault(arguments: LaunchArguments = .current()) -> AppEnvironment {
        NSLog(
            "Launch arguments resolved: isUITesting=%@, mode=%@, failure=%@",
            arguments.isUITesting ? "true" : "false",
            String(describing: arguments.galleryMode),
            String(describing: arguments.failureMode)
        )
        if arguments.isUITesting {
            return makeUITestEnvironment(arguments: arguments)
        }
        return makeProductionEnvironment()
    }

    private static func makeProductionEnvironment() -> AppEnvironment {
        do {
            let storage = try StorageAssembly.makeDefault()
            guard let endpoint = URL(string: "https://it-link.ru/test/images.txt") else {
                fatalError("Failed to create links endpoint URL")
            }
            let networking = NetworkingAssembly(linksEndpoint: endpoint)
            let gallery = GalleryDomainAssembly(networking: networking, storage: storage)
            let presentation = PresentationAssembly(domain: gallery, reachability: DefaultReachabilityService())
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

    private static func makeUITestEnvironment(arguments: LaunchArguments) -> AppEnvironment {
        do {
            let storage = try StorageAssembly.makeDefault()
            guard let endpoint = URL(string: "https://it-link.ru/test/images.txt") else {
                fatalError("Failed to create links endpoint URL")
            }
            let networking = NetworkingAssembly(linksEndpoint: endpoint)
            let configuration = UITestGalleryConfiguration(
                failureMode: arguments.failureMode,
                failureSequence: arguments.failureSequence
            )
            let repository = UITestGalleryRepository(configuration: configuration)
            let gallery = GalleryDomainAssembly(repository: repository)
            let reachability = UITestReachabilityService()
            let presentation = PresentationAssembly(domain: gallery, reachability: reachability)
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

import UIKit

struct GalleryPresentationAssembly {
    private let domain: GalleryDomainAssembly
    private let reachability: ReachabilityService

    init(domain: GalleryDomainAssembly, reachability: ReachabilityService = DefaultReachabilityService()) {
        self.domain = domain
        self.reachability = reachability
    }

    func makeRootViewController() -> UIViewController {
        let viewModel = GalleryViewModel(
            loadSnapshot: { try await domain.loadSnapshot.execute() },
            refreshSnapshot: { try await domain.refreshSnapshot.execute() }
        )
        let imageLoader = GalleryImageLoader(fetchImageData: domain.fetchImageData)
        return GalleryViewController(
            viewModel: viewModel,
            imageLoader: imageLoader,
            reachability: reachability
        )
    }
}

import UIKit

struct GalleryPresentationAssembly {
    private let domain: GalleryDomainAssembly

    init(domain: GalleryDomainAssembly) {
        self.domain = domain
    }

    func makeRootViewController() -> UIViewController {
        let viewModel = GalleryViewModel(
            loadSnapshot: { try await domain.loadSnapshot.execute() },
            refreshSnapshot: { try await domain.refreshSnapshot.execute() }
        )
        return GalleryViewController(viewModel: viewModel)
    }
}

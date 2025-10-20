import UIKit

struct GalleryPresentationAssembly {
    private let domain: GalleryDomainAssembly

    init(domain: GalleryDomainAssembly) {
        self.domain = domain
    }

    func makeRootViewController() -> UIViewController {
        GalleryViewController()
    }
}

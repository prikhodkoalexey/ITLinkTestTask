struct PresentationAssembly {
    let gallery: GalleryPresentationAssembly

    init(domain: GalleryDomainAssembly, reachability: ReachabilityService = DefaultReachabilityService()) {
        gallery = GalleryPresentationAssembly(domain: domain, reachability: reachability)
    }
}

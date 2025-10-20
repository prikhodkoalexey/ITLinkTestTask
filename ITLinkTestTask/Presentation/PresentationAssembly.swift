struct PresentationAssembly {
    let gallery: GalleryPresentationAssembly

    init(domain: GalleryDomainAssembly) {
        gallery = GalleryPresentationAssembly(domain: domain)
    }
}

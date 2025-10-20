import Foundation

struct GalleryViewState: Equatable {
    var isLoading: Bool
    var isRefreshing: Bool
    var content: GalleryViewContent
    var error: GalleryViewError?

    static let initial = GalleryViewState(
        isLoading: false,
        isRefreshing: false,
        content: .empty,
        error: nil
    )
}

struct GalleryViewError: Equatable {
    let message: String
    let isRetryAvailable: Bool
}

enum GalleryViewContent: Equatable {
    case empty
    case snapshot(GallerySnapshot)
}

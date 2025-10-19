import Foundation

enum LinkContentKind: Equatable {
    case image
    case nonImageURL
    case notURL
}

struct ImageLinkRecord: Equatable {
    let lineNumber: Int
    let originalText: String
    let url: URL?
    let contentKind: LinkContentKind
}

struct LinksFileSnapshot: Equatable {
    let sourceURL: URL
    let fetchedAt: Date
    let links: [ImageLinkRecord]
}

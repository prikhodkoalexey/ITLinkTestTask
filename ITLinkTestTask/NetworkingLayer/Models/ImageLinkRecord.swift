import Foundation

enum LinkContentKind: String, Codable, Equatable {
    case image
    case nonImageURL
    case notURL
}

struct ImageLinkRecord: Codable, Equatable {
    let lineNumber: Int
    let originalText: String
    let url: URL?
    let contentKind: LinkContentKind
}

struct LinksFileSnapshot: Codable, Equatable {
    let sourceURL: URL
    let fetchedAt: Date
    let links: [ImageLinkRecord]
}

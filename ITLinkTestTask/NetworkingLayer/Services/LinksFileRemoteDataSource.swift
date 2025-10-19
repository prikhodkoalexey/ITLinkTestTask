import Foundation

struct LinksFileRequest: HTTPRequest {
    let url: URL

    var urlRequest: URLRequest { URLRequest(url: url) }
}

protocol LinksFileRemoteDataSource {
    func fetchLinks() async throws -> LinksFileSnapshot
}

final class DefaultLinksFileRemoteDataSource: LinksFileRemoteDataSource {
    private let endpoint: URL
    private let client: HTTPClient
    private let acceptedContentTypes = ["text/plain", "text/*", "application/octet-stream"]

    init(endpoint: URL, client: HTTPClient) {
        self.endpoint = endpoint
        self.client = client
    }

    func fetchLinks() async throws -> LinksFileSnapshot {
        let response = try await client.perform(LinksFileRequest(url: endpoint))
        try validate(response: response.response)
        let lines = parseLines(from: response.data)
        let records = buildRecords(from: lines)
        return LinksFileSnapshot(sourceURL: endpoint, fetchedAt: Date(), links: records)
    }

    private func validate(response: HTTPURLResponse) throws {
        let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased()
        if let contentType, acceptedContentTypes.contains(where: { contentType.hasPrefix($0) }) {
            return
        }
        throw HTTPError.invalidContentType(expected: acceptedContentTypes, actual: response.value(forHTTPHeaderField: "Content-Type"))
    }

    private func parseLines(from data: Data) -> [String] {
        guard let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1251) else {
            return []
        }
        return content.components(separatedBy: .newlines)
    }

    private func buildRecords(from lines: [String]) -> [ImageLinkRecord] {
        var seen = Set<String>()
        var records: [ImageLinkRecord] = []

        for (idx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if !seen.insert(trimmed).inserted {
                continue
            }

            if let url = URL(string: trimmed) {
                if Self.isImageCandidate(url: url) {
                    records.append(ImageLinkRecord(lineNumber: idx + 1, originalText: trimmed, url: url, contentKind: .image))
                } else {
                    records.append(ImageLinkRecord(lineNumber: idx + 1, originalText: trimmed, url: url, contentKind: .nonImageURL))
                }
            } else {
                records.append(ImageLinkRecord(lineNumber: idx + 1, originalText: trimmed, url: nil, contentKind: .notURL))
            }
        }

        return records
    }

    private static func isImageCandidate(url: URL) -> Bool {
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "bmp", "webp", "heic"]
        let ext = url.pathExtension.lowercased()
        if !ext.isEmpty, imageExtensions.contains(ext) {
            return true
        }
        if let query = url.query?.lowercased(), imageExtensions.contains(where: { query.contains($0) }) {
            return true
        }
        return false
    }
}

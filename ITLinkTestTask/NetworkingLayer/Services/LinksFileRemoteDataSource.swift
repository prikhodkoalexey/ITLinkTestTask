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
        let lines = try parseLines(from: response.data)
        let records = buildRecords(from: lines)
        return LinksFileSnapshot(sourceURL: endpoint, fetchedAt: Date(), links: records)
    }

    private func validate(response: HTTPURLResponse) throws {
        let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased()
        if let contentType, acceptedContentTypes.contains(where: { contentType.hasPrefix($0) }) {
            return
        }
        let header = response.value(forHTTPHeaderField: "Content-Type")
        throw NetworkingError.invalidContentType(expected: acceptedContentTypes, actual: header)
    }

    private func parseLines(from data: Data) throws -> [String] {
        guard let content = decode(data: data) else {
            throw NetworkingError.invalidEncoding
        }
        return content.components(separatedBy: CharacterSet.newlines)
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

            if let url = normalize(urlString: trimmed) {
                if Self.isImageCandidate(url: url) {
                    records.append(
                        ImageLinkRecord(
                            lineNumber: idx + 1,
                            originalText: trimmed,
                            url: url,
                            contentKind: .image
                        )
                    )
                } else {
                    records.append(
                        ImageLinkRecord(
                            lineNumber: idx + 1,
                            originalText: trimmed,
                            url: url,
                            contentKind: .nonImageURL
                        )
                    )
                }
            } else {
                records.append(
                    ImageLinkRecord(
                        lineNumber: idx + 1,
                        originalText: trimmed,
                        url: nil,
                        contentKind: .notURL
                    )
                )
            }
        }

        return records
    }

    private func decode(data: Data) -> String? {
        String(data: data, encoding: .utf8)
    }

    private func normalize(urlString: String) -> URL? {
        if let direct = URL(string: urlString), isSupportedScheme(url: direct) {
            return direct
        }
        let allowed = CharacterSet.urlFragmentAllowed
            .union(.urlHostAllowed)
            .union(.urlPathAllowed)
            .union(.urlQueryAllowed)
        guard let encoded = urlString.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        guard let url = URL(string: encoded), isSupportedScheme(url: url) else {
            return nil
        }
        return url
    }

    private func isSupportedScheme(url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        if scheme == "http" || scheme == "https" {
            return true
        }
        return false
    }

    private static func isImageCandidate(url: URL) -> Bool {
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "bmp", "webp", "heic"]
        let ext = url.pathExtension.lowercased()
        if !ext.isEmpty, imageExtensions.contains(ext) {
            return true
        }
        let lowercasedPath = url.path.lowercased()
        if imageExtensions.contains(where: { lowercasedPath.contains($0) }) {
            return true
        }
        if let query = url.query?.lowercased(), imageExtensions.contains(where: { query.contains($0) }) {
            return true
        }
        if let host = url.host?.lowercased(), host.contains("gstatic.com") {
            if url.path.lowercased().contains("/images") {
                return true
            }
            if let query = url.query?.lowercased(), query.contains("q=tbn") {
                return true
            }
        }
        return false
    }
}

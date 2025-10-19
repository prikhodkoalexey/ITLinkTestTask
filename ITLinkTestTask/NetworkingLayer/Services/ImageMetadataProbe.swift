import Foundation

struct ImageMetadata {
    enum Format: String, Equatable {
        case png
        case jpeg
        case gif
        case webp
        case heic
        case bmp
        case unknown
    }

    let format: Format
    let mimeType: String?
    let originalURL: URL
}

protocol ImageMetadataProbe {
    func metadata(for url: URL) async throws -> ImageMetadata
}

final class DefaultImageMetadataProbe: ImageMetadataProbe {
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func metadata(for url: URL) async throws -> ImageMetadata {
        let response = try await client.perform(ImageMetadataRequest(url: url))
        let mime = normalizedMime(response.response.value(forHTTPHeaderField: "Content-Type"))
        let format = detectFormat(
            data: response.data,
            mime: mime,
            url: url
        )
        return ImageMetadata(format: format, mimeType: mime, originalURL: url)
    }

    private func normalizedMime(_ value: String?) -> String? {
        value?.split(separator: ";").first?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func detectFormat(data: Data, mime: String?, url: URL) -> ImageMetadata.Format {
        if let mime = mime?.lowercased() {
            if mime.contains("png") { return .png }
            if mime.contains("jpeg") || mime.contains("jpg") { return .jpeg }
            if mime.contains("gif") { return .gif }
            if mime.contains("webp") { return .webp }
            if mime.contains("heic") { return .heic }
            if mime.contains("bmp") { return .bmp }
        }

        if let pathFormat = formatFromPath(url.path) {
            return pathFormat
        }

        return signatureFormat(data: data)
    }

    private func formatFromPath(_ path: String) -> ImageMetadata.Format? {
        let mapping: [String: ImageMetadata.Format] = [
            "png": .png,
            "jpg": .jpeg,
            "jpeg": .jpeg,
            "gif": .gif,
            "webp": .webp,
            "heic": .heic,
            "bmp": .bmp
        ]
        let ext = (path as NSString).pathExtension.lowercased()
        return mapping[ext]
    }

    private func signatureFormat(data: Data) -> ImageMetadata.Format {
        guard data.count >= 12 else { return .unknown }
        let prefix = [UInt8](data.prefix(12))
        if prefix.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return .png
        }
        if prefix.starts(with: [0xFF, 0xD8]) {
            return .jpeg
        }
        if prefix.starts(with: [0x47, 0x49, 0x46, 0x38]) {
            return .gif
        }
        if prefix.starts(with: [0x52, 0x49, 0x46, 0x46]) && Array(prefix[8..<12]) == Array("WEBP".utf8) {
            return .webp
        }
        if prefix.starts(with: [0x00, 0x00, 0x00, 0x18]) && Array(prefix[4..<8]) == Array("ftyp".utf8) {
            return .heic
        }
        return .unknown
    }
}

private struct ImageMetadataRequest: HTTPRequest {
    let url: URL

    var urlRequest: URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("bytes=0-2047", forHTTPHeaderField: "Range")
        return request
    }
}

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
        let request = LinksFileRequest(url: url)
        let response = try await client.perform(request)
        let mime = response.response.value(forHTTPHeaderField: "Content-Type")
        let format = detectFormat(data: response.data, header: mime)
        return ImageMetadata(format: format, mimeType: mime, originalURL: url)
    }

    private func detectFormat(data: Data, header: String?) -> ImageMetadata.Format {
        if let header, header.contains("png") {
            return .png
        }
        if let header, header.contains("jpeg") || header.contains("jpg") {
            return .jpeg
        }
        if let header, header.contains("gif") {
            return .gif
        }
        if let header, header.contains("webp") {
            return .webp
        }
        if let header, header.contains("heic") {
            return .heic
        }
        if let header, header.contains("bmp") {
            return .bmp
        }
        return signatureFormat(data: data)
    }

    private func signatureFormat(data: Data) -> ImageMetadata.Format {
        guard data.count >= 12 else { return .unknown }
        let prefix = [UInt8](data.prefix(12))
        if prefix.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return .png
        }
        if prefix[0] == 0xFF, prefix[1] == 0xD8 {
            return .jpeg
        }
        if prefix.starts(with: [0x47, 0x49, 0x46, 0x38]) {
            return .gif
        }
        if prefix.starts(with: [0x52, 0x49, 0x46, 0x46]) && prefix[8...11] == Array("WEBP".utf8) {
            return .webp
        }
        if prefix.starts(with: [0x00, 0x00, 0x00, 0x18]) && prefix[4...7] == Array("ftyp".utf8) {
            return .heic
        }
        return .unknown
    }

}

import CoreGraphics
import Foundation
import ImageIO
import UIKit

final class GalleryImageLoader {
    private let fetchImageData: FetchGalleryImageDataUseCase
    private let cache = NSCache<NSURL, UIImage>()
    private let decodingQueue = DispatchQueue(label: "gallery.image.decoding", qos: .userInitiated)

    init(fetchImageData: FetchGalleryImageDataUseCase) {
        self.fetchImageData = fetchImageData
        cache.countLimit = 200
    }

    func image(for url: URL, targetSize: CGSize, scale: CGFloat) async throws -> UIImage {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        let data = try await fetchImageData.execute(url: url, variant: .thumbnail)
        let image = try await decodeImage(data: data, targetSize: targetSize, scale: scale)
        cache.setObject(image, forKey: url as NSURL)
        return image
    }

    private func decodeImage(data: Data, targetSize: CGSize, scale: CGFloat) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            decodingQueue.async {
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceThumbnailMaxPixelSize: Self.thumbnailPixelSize(for: targetSize, scale: scale)
                ]
                guard
                    let source = CGImageSourceCreateWithData(data as CFData, nil),
                    let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
                else {
                    continuation.resume(throwing: ImageDecodingError.failed)
                    return
                }
                continuation.resume(returning: UIImage(cgImage: cgImage, scale: scale, orientation: .up))
            }
        }
    }

    private static func thumbnailPixelSize(for size: CGSize, scale: CGFloat) -> Int {
        let maxDimension = max(size.width, size.height) * scale
        return max(1, Int(maxDimension.rounded(.up)))
    }

    enum ImageDecodingError: Error {
        case failed
    }
}

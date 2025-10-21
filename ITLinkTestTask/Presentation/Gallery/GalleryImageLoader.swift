import CoreGraphics
import Foundation
import ImageIO
import UIKit

enum ImageVariant {
    case thumbnail(targetSize: CGSize, scale: CGFloat)
    case original
}

final class GalleryImageLoader {
    private let fetchImageData: FetchGalleryImageDataUseCase
    private let cache = NSCache<NSString, UIImage>()
    private let decodingQueue = DispatchQueue(label: "gallery.image.decoding", qos: .userInitiated)

    init(fetchImageData: FetchGalleryImageDataUseCase) {
        self.fetchImageData = fetchImageData
        cache.countLimit = 200
    }

    func image(
        for url: URL,
        variant: ImageVariant = .thumbnail(targetSize: CGSize(width: 150, height: 150), scale: 1.0)
    ) async throws -> UIImage {
        let cacheKey = makeCacheKey(for: url, variant: variant)

        if let cached = cache.object(forKey: cacheKey as NSString) {
            return cached
        }

        let imageDataVariant: ImageDataVariant
        switch variant {
        case .original:
            imageDataVariant = .original
        case .thumbnail:
            imageDataVariant = .thumbnail
        }
        let data = try await fetchImageData.execute(
            url: url,
            variant: imageDataVariant
        )
        let image = try await decodeImage(data: data, variant: variant)

        cache.setObject(image, forKey: cacheKey as NSString)
        return image
    }
    
    private func makeCacheKey(for url: URL, variant: ImageVariant) -> String {
        switch variant {
        case .thumbnail(let targetSize, let scale):
            return "\(url.absoluteString)_thumbnail_\(Int(targetSize.width))x\(Int(targetSize.height))_\(scale)"
        case .original:
            return "\(url.absoluteString)_original"
        }
    }

    private func decodeImage(data: Data, variant: ImageVariant) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            decodingQueue.async {
                switch variant {
                case .original:
                    guard
                        let source = CGImageSourceCreateWithData(data as CFData, nil),
                        let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
                    else {
                        continuation.resume(throwing: ImageDecodingError.failed)
                        return
                    }
                    let image = UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
                    continuation.resume(returning: image)

                case .thumbnail(let targetSize, let scale):
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
    }

    private static func thumbnailPixelSize(for size: CGSize, scale: CGFloat) -> Int {
        let maxDimension = max(size.width, size.height) * scale
        return max(1, Int(maxDimension.rounded(.up)))
    }

    enum ImageDecodingError: Error {
        case failed
    }
}

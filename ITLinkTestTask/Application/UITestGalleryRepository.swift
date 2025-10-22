import Foundation
import UIKit

struct UITestGalleryConfiguration {
    let failureMode: LaunchArguments.FailureMode
    let failureSequence: [LaunchArguments.FailureStep]
}

actor UITestGalleryRepository: GalleryRepository {
    private struct CacheKey: Hashable {
        let url: URL
        let variant: ImageDataVariant
    }

    private let configuration: UITestGalleryConfiguration
    private let snapshot: GallerySnapshot
    private var didFailOnce = false
    private var remainingSequence: [LaunchArguments.FailureStep]
    private var cachedImageData: [CacheKey: Data] = [:]

    init(configuration: UITestGalleryConfiguration) {
        self.configuration = configuration
        self.snapshot = Self.makeSnapshot()
        self.remainingSequence = configuration.failureSequence
    }

    func loadInitialSnapshot() async throws -> GallerySnapshot {
        NSLog("UITestGalleryRepository loadInitialSnapshot")
        try evaluateFailure()
        return snapshot
    }

    func refreshSnapshot() async throws -> GallerySnapshot {
        NSLog("UITestGalleryRepository refreshSnapshot")
        try evaluateFailure()
        return snapshot
    }

    func imageData(for url: URL, variant: ImageDataVariant) async throws -> Data {
        let key = CacheKey(url: url, variant: variant)
        if let cached = cachedImageData[key] {
            return cached
        }
        let data: Data
        switch variant {
        case .original:
            data = await Self.renderImageData(for: url)
        case .thumbnail(let maxPixelSize):
            let original = try await imageData(for: url, variant: .original)
            data = await Self.renderThumbnailData(from: original, maxPixelSize: maxPixelSize)
        }
        cachedImageData[key] = data
        return data
    }

    func metadata(for url: URL) async throws -> ImageMetadata {
        ImageMetadata(format: .png, mimeType: "image/png", originalURL: url)
    }

    private func evaluateFailure() throws {
        if !remainingSequence.isEmpty {
            let step = remainingSequence.removeFirst()
            switch step {
            case .fail:
                NSLog("UI test stub: sequence step fail")
                throw NetworkingError.invalidURL("ui-test")
            case .success:
                NSLog("UI test stub: sequence step success")
                return
            }
        }
        switch configuration.failureMode {
        case .none:
            return
        case .always:
            NSLog("UI test stub: forcing error (always mode)")
            throw NetworkingError.invalidURL("ui-test")
        case .once:
            if didFailOnce {
                NSLog("UI test stub: allowing success after initial failure")
                return
            }
            didFailOnce = true
            NSLog("UI test stub: triggering one-time failure")
            throw NetworkingError.invalidURL("ui-test")
        }
    }

    private static func makeSnapshot() -> GallerySnapshot {
        guard let sourceURL = URL(string: "https://ui-test.local/gallery.txt") else {
            fatalError("Failed to build UI test source URL")
        }
        return GallerySnapshot(
            sourceURL: sourceURL,
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000),
            items: sampleItems()
        )
    }

    private static func sampleItems() -> [GalleryItem] {
        guard
            let firstImageURL = URL(string: "https://ui-test.local/image-1.png"),
            let secondImageURL = URL(string: "https://ui-test.local/image-2.png"),
            let thirdImageURL = URL(string: "https://ui-test.local/image-3.png")
        else {
            fatalError("Failed to build UI test URLs")
        }
        let imageItem: (URL, Int) -> GalleryItem = { url, line in
            .image(
                GalleryImage(
                    url: url,
                    originalLine: url.absoluteString,
                    lineNumber: line
                )
            )
        }
        let placeholderItem: (String, Int, GalleryPlaceholderReason) -> GalleryItem = { text, line, reason in
            .placeholder(
                GalleryPlaceholder(
                    originalLine: text,
                    lineNumber: line,
                    reason: reason
                )
            )
        }
        return [
            imageItem(firstImageURL, 1),
            imageItem(secondImageURL, 2),
            placeholderItem("не ссылка на изображение", 3, .nonImageURL),
            imageItem(thirdImageURL, 4),
            placeholderItem("not a url", 5, .invalidContent)
        ]
    }

    private nonisolated static func renderImageData(for url: URL) async -> Data {
        await MainActor.run {
            let size = CGSize(width: 360, height: 360)
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { context in
                let bounds = CGRect(origin: .zero, size: size)
                let backgroundColor = Self.color(for: url)
                backgroundColor.setFill()
                context.fill(bounds)

                let stripeColor = backgroundColor.withAlphaComponent(0.4)
                stripeColor.setFill()
                let stripePath = UIBezierPath()
                stripePath.move(to: CGPoint(x: 0, y: size.height * 0.65))
                stripePath.addLine(to: CGPoint(x: size.width, y: size.height * 0.45))
                stripePath.addLine(to: CGPoint(x: size.width, y: size.height))
                stripePath.addLine(to: CGPoint(x: 0, y: size.height))
                stripePath.close()
                stripePath.fill()

                let indexString = Self.indexLabel(for: url)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: size.width / 3.2, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                let textSize = indexString.size(withAttributes: attributes)
                let textOrigin = CGPoint(
                    x: (size.width - textSize.width) / 2,
                    y: (size.height - textSize.height) / 2
                )
                indexString.draw(at: textOrigin, withAttributes: attributes)
            }
            return image.pngData() ?? Data()
        }
    }

    private nonisolated static func renderThumbnailData(from data: Data, maxPixelSize: Int) async -> Data {
        await MainActor.run {
            guard let image = UIImage(data: data) else { return data }
            let maxDimension = max(1, maxPixelSize)
            let originalMax = max(image.size.width, image.size.height)
            let scale = originalMax == 0 ? 1 : min(1, CGFloat(maxDimension) / originalMax)
            let targetSize = CGSize(
                width: max(1, image.size.width * scale),
                height: max(1, image.size.height * scale)
            )
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            let thumbnail = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            return thumbnail.pngData() ?? data
        }
    }

    private nonisolated static func indexLabel(for url: URL) -> NSString {
        let number = (sampleIndex(for: url) % 99) + 1
        return NSString(string: "\(number)")
    }

    private nonisolated static func color(for url: URL) -> UIColor {
        let palette: [UIColor] = [
            UIColor(red: 0.23, green: 0.52, blue: 0.96, alpha: 1),
            UIColor(red: 0.18, green: 0.78, blue: 0.45, alpha: 1),
            UIColor(red: 0.88, green: 0.32, blue: 0.39, alpha: 1),
            UIColor(red: 0.93, green: 0.66, blue: 0.26, alpha: 1),
            UIColor(red: 0.55, green: 0.39, blue: 0.95, alpha: 1)
        ]
        let index = sampleIndex(for: url) % palette.count
        return palette[index]
    }

    private nonisolated static func sampleIndex(for url: URL) -> Int {
        let name = url.deletingPathExtension().lastPathComponent
        let tokens = name.split(separator: "-")
        if let last = tokens.last, let number = Int(last) {
            return max(0, number - 1)
        }
        var hash = 0
        for scalar in url.absoluteString.unicodeScalars {
            hash = (hash &* 31 &+ Int(scalar.value)) & 0x7FFFFFFF
        }
        return hash
    }
}

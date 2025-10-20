import Foundation

struct UITestGalleryConfiguration {
    let failureMode: LaunchArguments.FailureMode
    let failureSequence: [LaunchArguments.FailureStep]
}

actor UITestGalleryRepository: GalleryRepository {
    private let configuration: UITestGalleryConfiguration
    private let snapshot: GallerySnapshot
    private let imageData: Data
    private var didFailOnce = false
    private var remainingSequence: [LaunchArguments.FailureStep]

    init(configuration: UITestGalleryConfiguration) {
        self.configuration = configuration
        self.imageData = Self.makeImageData()
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
        imageData
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

    private static func makeImageData() -> Data {
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAocB9pG5BxwAAAAASUVORK5CYII="
        guard let data = Data(base64Encoded: base64) else {
            fatalError("Failed to decode sample image data")
        }
        return data
    }
}

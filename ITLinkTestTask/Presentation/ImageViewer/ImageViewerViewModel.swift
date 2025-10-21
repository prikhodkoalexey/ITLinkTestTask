import UIKit

enum ImageViewerPageState {
    case idle
    case loading(UIImage?)
    case loaded(UIImage)
    case failed(UIImage?)
}

@MainActor
final class ImageViewerViewModel {
    private nonisolated let imageLoader: GalleryImageLoading
    private let urls: [URL]
    private var tasks: [Int: Task<Void, Never>] = [:]
    private var states: [ImageViewerPageState]

    private(set) var currentIndex: Int

    var onPageStateChange: ((Int, ImageViewerPageState) -> Void)?
    var onCurrentIndexChange: ((Int) -> Void)?

    init(imageLoader: GalleryImageLoading, imageURL: URL, allImageURLs: [URL], currentIndex: Int) {
        self.imageLoader = imageLoader
        self.urls = allImageURLs
        let resolvedIndex: Int
        if let index = allImageURLs.firstIndex(of: imageURL) {
            resolvedIndex = index
        } else {
            resolvedIndex = min(max(0, currentIndex), max(0, allImageURLs.count - 1))
        }
        self.currentIndex = resolvedIndex
        self.states = Array(repeating: .idle, count: allImageURLs.count)
    }

    var totalImagesCount: Int {
        urls.count
    }

    func start() {
        guard totalImagesCount > 0 else { return }
        loadItem(at: currentIndex)
        loadSurroundings()
    }

    func state(at index: Int) -> ImageViewerPageState {
        guard index >= 0, index < states.count else { return .idle }
        return states[index]
    }

    func loadItem(at index: Int) {
        guard index >= 0, index < urls.count else { return }
        if let task = tasks[index], !task.isCancelled { return }
        let currentState = states[index]
        switch currentState {
        case .loaded:
            return
        case .loading where tasks[index] != nil:
            return
        default:
            break
        }
        let existing: UIImage?
        switch currentState {
        case .loaded(let image):
            existing = image
        case .loading(let image):
            existing = image
        case .failed(let image):
            existing = image
        case .idle:
            existing = nil
        }
        updateState(.loading(existing), at: index)
        let url = urls[index]
        let existingImage = existing
        let loader = imageLoader
        tasks[index] = Task { [weak self] in
            let result: Result<UIImage, Error>
            do {
                let image = try await loader.image(for: url, variant: .original)
                result = .success(image)
            } catch {
                result = .failure(error)
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                switch result {
                case .success(let image):
                    self.updateState(.loaded(image), at: index)
                case .failure:
                    self.updateState(.failed(existingImage), at: index)
                }
                self.tasks[index] = nil
            }
        }
    }

    func retryItem(at index: Int) {
        cancelItem(at: index)
        updateState(.idle, at: index)
        loadItem(at: index)
    }

    func cancelItem(at index: Int) {
        if let task = tasks[index] {
            task.cancel()
        }
        tasks[index] = nil
    }

    func updateCurrentIndex(_ index: Int) {
        guard index >= 0, index < urls.count else { return }
        guard currentIndex != index else { return }
        currentIndex = index
        onCurrentIndexChange?(index)
        loadItem(at: index)
        loadSurroundings()
    }

    func loadSurroundings() {
        let neighbors = [currentIndex - 1, currentIndex + 1]
        for index in neighbors where index >= 0 && index < urls.count {
            loadItem(at: index)
        }
    }

    func shareURL(for index: Int) -> URL? {
        guard index >= 0, index < urls.count else { return nil }
        return urls[index]
    }

    deinit {
        tasks.values.forEach { $0.cancel() }
    }

    private func updateState(_ state: ImageViewerPageState, at index: Int) {
        guard index >= 0, index < states.count else { return }
        states[index] = state
        onPageStateChange?(index, state)
    }
}

import UIKit

extension GalleryViewController {
    func makeDataSource() -> UICollectionViewDiffableDataSource<Int, Int> {
        UICollectionViewDiffableDataSource(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, identifier in
            guard
                let self,
                identifier < currentItems.count
            else { return nil }
            let item = currentItems[identifier]
            switch item {
            case let .image(image):
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: GalleryImageCell.reuseIdentifier,
                    for: indexPath
                ) as? GalleryImageCell else {
                    return nil
                }
                configureImageCell(cell, with: image)
                return cell
            case let .placeholder(placeholder):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: GalleryPlaceholderCell.reuseIdentifier,
                    for: indexPath
                ) as? GalleryPlaceholderCell
                cell?.configure(with: placeholder)
                return cell
            }
        }
    }

    func configureImageCell(_ cell: GalleryImageCell, with image: GalleryImage) {
        cell.configure(image: nil, accessibilityLabel: image.originalLine)
        cell.onRetry = { [weak self, weak cell] in
            guard let self, let cell, let indexPath = collectionView.indexPath(for: cell) else { return }
            failedThumbnailURLs.remove(image.url)
            cell.configure(image: nil, accessibilityLabel: image.originalLine)
            loadImage(for: image, at: indexPath, cell: cell)
        }
        if failedThumbnailURLs.contains(image.url) {
            cell.showErrorOverlay()
        }
    }

    func applySnapshot(with items: [GalleryItem]) {
        currentItems = items
        let validURLs = Set(items.compactMap { item -> URL? in
            if case .image(let image) = item {
                return image.url
            }
            return nil
        })
        failedThumbnailURLs = failedThumbnailURLs.intersection(validURLs)
        var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
        snapshot.appendSections([0])
        snapshot.appendItems(Array(items.indices), toSection: 0)
        dataSource.apply(snapshot, animatingDifferences: true) { [weak self] in
            guard let self else { return }
            let visible = Set(collectionView.indexPathsForVisibleItems)
            cleanupUnusedImageTasks(validIndexPaths: visible)
            preloadVisibleImages()
        }
    }

    func loadImage(for image: GalleryImage, at indexPath: IndexPath, cell: GalleryImageCell) {
        imageTasks[indexPath]?.cancel()
        let targetSize = layout.itemSize == .zero
            ? CGSize(width: LayoutConstants.maxItemWidth, height: LayoutConstants.maxItemWidth)
            : layout.itemSize
        let scale = view.window?.screen.scale ?? UIScreen.main.scale
        let task = Task { [weak self, weak cell] in
            guard let self else { return }
            do {
                let uiImage = try await imageLoader.image(
                    for: image.url,
                    variant: .thumbnail(targetSize: targetSize, scale: scale)
                )
                await MainActor.run {
                    guard
                        let cell,
                        let identifier = dataSource.itemIdentifier(for: indexPath),
                        identifier < currentItems.count,
                        case let .image(currentImage) = currentItems[identifier],
                        currentImage == image
                    else { return }
                    failedThumbnailURLs.remove(image.url)
                    cell.configure(image: uiImage, accessibilityLabel: image.originalLine)
                }
            } catch {
                await MainActor.run {
                    guard let cell else { return }
                    failedThumbnailURLs.insert(image.url)
                    cell.configure(image: nil, accessibilityLabel: image.originalLine)
                    configureImageCell(cell, with: image)
                }
            }
            await MainActor.run { [weak self] in
                self?.imageTasks[indexPath] = nil
            }
        }
        imageTasks[indexPath] = task
    }

    func cleanupUnusedImageTasks(validIndexPaths: Set<IndexPath>) {
        let keysToCancel = imageTasks.keys.filter { !validIndexPaths.contains($0) }
        for key in keysToCancel {
            imageTasks[key]?.cancel()
            imageTasks[key] = nil
        }
    }

    func preloadVisibleImages() {
        collectionView.layoutIfNeeded()
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard
                let identifier = dataSource.itemIdentifier(for: indexPath),
                identifier < currentItems.count,
                case let .image(image) = currentItems[identifier],
                let cell = collectionView.cellForItem(at: indexPath) as? GalleryImageCell,
                imageTasks[indexPath] == nil
            else { continue }
            if failedThumbnailURLs.contains(image.url) {
                cell.showErrorOverlay()
                continue
            }
            loadImage(for: image, at: indexPath, cell: cell)
        }
    }
}

extension GalleryViewController: UICollectionViewDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard
            let identifier = dataSource.itemIdentifier(for: indexPath),
            identifier < currentItems.count,
            case let .image(image) = currentItems[identifier],
            let imageCell = cell as? GalleryImageCell
        else { return }
        configureImageCell(imageCell, with: image)
        if failedThumbnailURLs.contains(image.url) {
            imageCell.showErrorOverlay()
            return
        }
        loadImage(for: image, at: indexPath, cell: imageCell)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didEndDisplaying cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        imageTasks[indexPath]?.cancel()
        imageTasks[indexPath] = nil
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < currentItems.count else { return }
        let item = currentItems[indexPath.item]
        switch item {
        case .image(let image):
            let allImageURLs = currentItems.compactMap { galleryItem in
                if case .image(let galleryImage) = galleryItem {
                    return galleryImage.url
                }
                return nil
            }
            let currentIndex = currentItems.firstIndex { galleryItem in
                if case .image(let galleryImage) = galleryItem {
                    return galleryImage.url == image.url
                }
                return false
            } ?? 0
            if failedThumbnailURLs.contains(image.url) {
                if let cell = collectionView.cellForItem(at: indexPath) as? GalleryImageCell {
                    cell.onRetry?()
                }
                return
            }
            let imageViewerAssembly = ImageViewerAssembly(galleryImageLoader: imageLoader)
            let imageViewerViewController = imageViewerAssembly.makeImageViewerViewController(
                imageURL: image.url,
                allImageURLs: allImageURLs,
                currentIndex: currentIndex
            )
            navigationController?.pushViewController(imageViewerViewController, animated: true)
        case .placeholder:
            break
        }
    }
}

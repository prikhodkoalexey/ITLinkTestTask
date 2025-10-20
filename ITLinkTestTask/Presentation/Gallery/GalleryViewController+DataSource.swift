import UIKit

extension GalleryViewController {
    enum SnapshotItem: Hashable {
        case image(GalleryImage)
        case placeholder(GalleryPlaceholder)
    }

    func makeDataSource() -> UICollectionViewDiffableDataSource<Section, SnapshotItem> {
        UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case let .image(image):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: GalleryImageCell.reuseIdentifier,
                    for: indexPath
                ) as? GalleryImageCell
                cell?.configure(image: nil, accessibilityLabel: image.originalLine)
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

    func applySnapshot(with items: [SnapshotItem]) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, SnapshotItem>()
        snapshot.appendSections([.main])
        snapshot.appendItems(items, toSection: .main)
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
                    targetSize: targetSize,
                    scale: scale
                )
                await MainActor.run {
                    guard
                        let cell,
                        let current = dataSource.itemIdentifier(for: indexPath),
                        case let .image(currentImage) = current,
                        currentImage == image
                    else { return }
                    cell.configure(image: uiImage, accessibilityLabel: image.originalLine)
                }
            } catch {
                await MainActor.run {
                    guard let cell else { return }
                    cell.configure(image: nil, accessibilityLabel: image.originalLine)
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
                let item = dataSource.itemIdentifier(for: indexPath),
                case let .image(image) = item,
                let cell = collectionView.cellForItem(at: indexPath) as? GalleryImageCell,
                imageTasks[indexPath] == nil
            else { continue }
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
            let item = dataSource.itemIdentifier(for: indexPath),
            case let .image(image) = item,
            let imageCell = cell as? GalleryImageCell
        else { return }
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
}

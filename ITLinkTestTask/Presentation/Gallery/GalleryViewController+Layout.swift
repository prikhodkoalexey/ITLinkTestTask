import UIKit

extension GalleryViewController {
    enum LayoutConstants {
        static let spacing: CGFloat = 8
        static let minItemWidth: CGFloat = 100
        static let maxItemWidth: CGFloat = 120
        static let sectionInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
    }

    struct GridConfiguration {
        let itemWidth: CGFloat
        let insets: UIEdgeInsets
    }

    func updateItemSize(for availableWidth: CGFloat) {
        guard availableWidth > 0 else { return }
        let configuration = makeGridConfiguration(for: availableWidth)
        layout.sectionInset = configuration.insets
        layout.itemSize = CGSize(width: configuration.itemWidth, height: configuration.itemWidth)
    }

    func makeGridConfiguration(for width: CGFloat) -> GridConfiguration {
        let insets = LayoutConstants.sectionInsets
        let contentWidth = width - insets.left - insets.right
        let spacing = LayoutConstants.spacing
        let minColumns = 1
        let maxColumns = 8
        let targetWidth = (LayoutConstants.minItemWidth + LayoutConstants.maxItemWidth) / 2
        var bestColumns = 1
        var bestScore = CGFloat.greatestFiniteMagnitude
        var bestWidth = max(LayoutConstants.minItemWidth, min(contentWidth, LayoutConstants.maxItemWidth))

        for columns in minColumns...maxColumns {
            let totalSpacing = CGFloat(columns - 1) * spacing
            let candidateWidth = (contentWidth - totalSpacing) / CGFloat(columns)
            if candidateWidth < LayoutConstants.minItemWidth {
                break
            }
            let clampedWidth = min(
                max(candidateWidth, LayoutConstants.minItemWidth),
                LayoutConstants.maxItemWidth
            )
            let withinBounds = candidateWidth >= LayoutConstants.minItemWidth &&
                candidateWidth <= LayoutConstants.maxItemWidth
            let penalty: CGFloat = withinBounds ? 0 : 100
            let score = abs(clampedWidth - targetWidth) + penalty
            if score < bestScore {
                bestScore = score
                bestColumns = columns
                bestWidth = clampedWidth
            }
        }

        let totalSpacing = CGFloat(bestColumns - 1) * spacing
        let adjustedWidth = min(
            (contentWidth - totalSpacing) / CGFloat(bestColumns),
            bestWidth
        )
        return GridConfiguration(
            itemWidth: adjustedWidth,
            insets: insets
        )
    }
}

import UIKit

final class GalleryImageCell: UICollectionViewCell {
    static let reuseIdentifier = "GalleryImageCell"

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .secondarySystemBackground
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        accessibilityIdentifier = GalleryViewController.Accessibility.imageCell
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
    }

    func configure(image: UIImage?, accessibilityLabel: String?) {
        imageView.image = image
        imageView.accessibilityLabel = accessibilityLabel
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        imageView.accessibilityLabel = nil
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class GalleryPlaceholderCell: UICollectionViewCell {
    static let reuseIdentifier = "GalleryPlaceholderCell"

    private let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = UIFont.preferredFont(forTextStyle: .caption1)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.text = "Нет превью"
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        accessibilityIdentifier = GalleryViewController.Accessibility.placeholderCell
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func configure(with placeholder: GalleryPlaceholder) {
        switch placeholder.reason {
        case .nonImageURL:
            label.text = "Ссылка не на изображение"
        case .invalidContent:
            label.text = "Некорректная запись"
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

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
    private let overlayView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemThinMaterial)
        let view = UIVisualEffectView(effect: blur)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        view.isUserInteractionEnabled = true
        return view
    }()
    private let overlayStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        return stack
    }()
    private let overlayIcon: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "arrow.clockwise"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .label
        return imageView
    }()
    private let overlayLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .caption1)
        label.textColor = .label
        label.textAlignment = .center
        label.text = "Ошибка превью"
        return label
    }()
    let retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Повторить", for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .caption1)
        button.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.9)
        button.layer.cornerRadius = 12
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        return button
    }()
    var onRetry: (() -> Void)?
    private var overlayTapRecognizer: UITapGestureRecognizer!

    override init(frame: CGRect) {
        super.init(frame: frame)
        accessibilityIdentifier = GalleryViewController.Accessibility.imageCell
        contentView.addSubview(imageView)
        contentView.addSubview(overlayView)
        overlayView.contentView.addSubview(overlayStack)
        overlayStack.addArrangedSubview(overlayIcon)
        overlayStack.addArrangedSubview(overlayLabel)
        overlayStack.addArrangedSubview(retryButton)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            overlayView.topAnchor.constraint(equalTo: contentView.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            overlayStack.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            overlayStack.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor)
        ])
        retryButton.accessibilityIdentifier = GalleryViewController.Accessibility.thumbnailRetryButton
        retryButton.addTarget(self, action: #selector(handleRetry), for: .touchUpInside)
        overlayTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleRetry))
        overlayView.addGestureRecognizer(overlayTapRecognizer)
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
    }

    func configure(image: UIImage?, accessibilityLabel: String?) {
        imageView.image = image
        imageView.accessibilityLabel = accessibilityLabel
        overlayView.isHidden = true
    }

    func showErrorOverlay(message: String = "Ошибка превью") {
        overlayLabel.text = message
        overlayView.isHidden = false
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        imageView.accessibilityLabel = nil
        overlayView.isHidden = true
        onRetry = nil
    }

    @objc private func handleRetry() {
        onRetry?()
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

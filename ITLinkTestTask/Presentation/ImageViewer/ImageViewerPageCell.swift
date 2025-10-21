import UIKit

final class ImageViewerPageCell: UICollectionViewCell, UIScrollViewDelegate {
    static let reuseIdentifier = "ImageViewerPageCell"

    var onRetry: (() -> Void)?
    var onSingleTap: (() -> Void)?
    var onDoubleTap: ((CGPoint) -> Void)?

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.maximumZoomScale = 3
        scrollView.minimumZoomScale = 1
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        return scrollView
    }()

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = true
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        return imageView
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private let errorButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Повторить", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        button.layer.cornerRadius = 16
        button.isHidden = true
        return button
    }()

    private var singleTapRecognizer: UITapGestureRecognizer!
    private var doubleTapRecognizer: UITapGestureRecognizer!

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 3
        scrollView.zoomScale = 1
        scrollView.contentInset = .zero
        scrollView.contentSize = scrollView.bounds.size
        imageView.image = nil
        imageView.frame = .zero
        errorButton.isHidden = true
        imageView.tintColor = nil
        activityIndicator.stopAnimating()
    }

    func configure(with state: ImageViewerPageState) {
        switch state {
        case .idle:
            activityIndicator.stopAnimating()
            imageView.image = nil
            imageView.tintColor = nil
            errorButton.isHidden = true
        case .loading(let existingImage):
            if let existingImage {
                imageView.image = existingImage
                imageView.tintColor = nil
            }
            activityIndicator.startAnimating()
            errorButton.isHidden = true
        case .loaded(let image):
            activityIndicator.stopAnimating()
            errorButton.isHidden = true
            imageView.image = image
            imageView.tintColor = nil
            adjustImageLayout()
        case .failed(let placeholder):
            activityIndicator.stopAnimating()
            let fallback = placeholder ?? UIImage(
                systemName: "exclamationmark.triangle.fill"
            )?.withRenderingMode(.alwaysTemplate)
            imageView.image = fallback
            imageView.tintColor = .white
            errorButton.isHidden = false
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        adjustImageLayout()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        adjustImageLayout()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
    }

    func resetZoom() {
        scrollView.setZoomScale(scrollView.minimumZoomScale, animated: false)
        centerImage()
    }

    func prepareForDisplay() {
        adjustImageLayout()
    }

    private func configure() {
        backgroundColor = .clear
        contentView.backgroundColor = .black
        scrollView.delegate = self
        scrollView.contentInsetAdjustmentBehavior = .never
        contentView.addSubview(scrollView)
        scrollView.addSubview(imageView)
        contentView.addSubview(activityIndicator)
        contentView.addSubview(errorButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            errorButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            errorButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])

        singleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapRecognizer.numberOfTapsRequired = 2
        singleTapRecognizer.require(toFail: doubleTapRecognizer)

        contentView.addGestureRecognizer(singleTapRecognizer)
        contentView.addGestureRecognizer(doubleTapRecognizer)

        errorButton.addTarget(self, action: #selector(handleRetry), for: .touchUpInside)
    }

    private func adjustImageLayout() {
        guard let image = imageView.image else {
            imageView.frame = CGRect(origin: .zero, size: scrollView.bounds.size)
            centerImage()
            return
        }
        let scrollSize = scrollView.bounds.size
        guard scrollSize.width > 0, scrollSize.height > 0 else { return }
        let imageSize = image.size
        let widthScale = scrollSize.width / imageSize.width
        let heightScale = scrollSize.height / imageSize.height
        let fitScale = min(widthScale, heightScale)
        guard fitScale.isFinite, fitScale > 0 else { return }
        let fittedSize = CGSize(
            width: imageSize.width * fitScale,
            height: imageSize.height * fitScale
        )
        imageView.frame = CGRect(origin: .zero, size: fittedSize)
        scrollView.contentSize = fittedSize
        let minimumScale: CGFloat = 1
        let maximumScale = max(3, 1 / fitScale)
        scrollView.minimumZoomScale = minimumScale
        scrollView.maximumZoomScale = maximumScale
        scrollView.setZoomScale(minimumScale, animated: false)
        centerImage()
    }

    private func centerImage() {
        let scrollSize = scrollView.bounds.size
        let imageFrame = imageView.frame
        let verticalInset = max(0, (scrollSize.height - imageFrame.height) / 2)
        let horizontalInset = max(0, (scrollSize.width - imageFrame.width) / 2)
        scrollView.contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
    }

    @objc private func handleSingleTap() {
        onSingleTap?()
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: imageView)
        onDoubleTap?(location)
    }

    @objc private func handleRetry() {
        onRetry?()
    }

    func zoom(at point: CGPoint) {
        let targetScale = scrollView.zoomScale == scrollView.minimumZoomScale
            ? scrollView.maximumZoomScale
            : scrollView.minimumZoomScale
        if targetScale == scrollView.minimumZoomScale {
            scrollView.setZoomScale(targetScale, animated: true)
            return
        }
        let clampedX = max(0, min(point.x, imageView.bounds.width))
        let clampedY = max(0, min(point.y, imageView.bounds.height))
        let size = CGSize(
            width: scrollView.bounds.width / targetScale,
            height: scrollView.bounds.height / targetScale
        )
        let origin = CGPoint(
            x: clampedX - size.width / 2,
            y: clampedY - size.height / 2
        )
        let rect = CGRect(origin: origin, size: size)
        scrollView.zoom(to: rect, animated: true)
    }
}

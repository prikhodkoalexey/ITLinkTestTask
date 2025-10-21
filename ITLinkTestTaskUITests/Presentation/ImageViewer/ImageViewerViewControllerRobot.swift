import XCTest

final class ImageViewerViewRobot {
    private let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    @discardableResult
    func waitForViewer(timeout: TimeInterval = 10) -> Self {
        XCTAssertTrue(collectionView().waitForExistence(timeout: timeout))
        XCTAssertTrue(imageView().waitForExistence(timeout: timeout))
        return self
    }

    @discardableResult
    func waitForActivityIndicator(timeout: TimeInterval = 10) -> Self {
        XCTAssertTrue(activityIndicator().waitForExistence(timeout: timeout))
        return self
    }

    @discardableResult
    func waitForBackButton(timeout: TimeInterval = 10) -> Self {
        XCTAssertTrue(backButton().waitForExistence(timeout: timeout))
        return self
    }

    @discardableResult
    func waitForChromeVisible(timeout: TimeInterval = 5) -> Self {
        XCTAssertTrue(backButton().waitForExistence(timeout: timeout))
        XCTAssertTrue(shareButton().waitForExistence(timeout: timeout))
        XCTAssertTrue(fullscreenButton().waitForExistence(timeout: timeout))
        XCTAssertTrue(pageControl().waitForExistence(timeout: timeout))
        XCTAssertTrue(isChromeVisible())
        return self
    }

    @discardableResult
    func waitForChromeHidden(timeout: TimeInterval = 5) -> Self {
        let predicate = NSPredicate(format: "isHittable == false")
        let elements = [backButton(), shareButton(), fullscreenButton(), pageControl()]
        elements.forEach { element in
            let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
            let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
            XCTAssertEqual(result, .completed)
        }
        XCTAssertTrue(isChromeHidden())
        return self
    }

    @discardableResult
    func tapBackButton() -> Self {
        backButton().tap()
        return self
    }

    @discardableResult
    func tapShareButton() -> Self {
        shareButton().tap()
        return self
    }

    @discardableResult
    func tapFullscreenButton() -> Self {
        fullscreenButton().tap()
        return self
    }

    @discardableResult
    func tapImageView() -> Self {
        imageView().tap()
        return self
    }

    @discardableResult
    func doubleTapImageView() -> Self {
        imageView().doubleTap()
        return self
    }

    @discardableResult
    func pinchImageView(scale: CGFloat) -> Self {
        imageView().pinch(withScale: scale, velocity: 1.0)
        return self
    }

    @discardableResult
    func swipeLeft() -> Self {
        imageView().swipeLeft()
        return self
    }

    @discardableResult
    func swipeRight() -> Self {
        imageView().swipeRight()
        return self
    }

    @discardableResult
    func waitForShareSheet(timeout: TimeInterval = 5) -> Self {
        XCTAssertTrue(shareSheet().waitForExistence(timeout: timeout))
        return self
    }

    @discardableResult
    func waitForPage(index: Int, timeout: TimeInterval = 5) -> Self {
        let predicate = NSPredicate { _, _ in
            self.pageProgress()?.current == index
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: pageControl())
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed)
        XCTAssertEqual(pageProgress()?.current, index)
        return self
    }

    func isShareSheetPresented() -> Bool {
        shareSheet().exists
    }

    func isImageViewExists() -> Bool {
        imageView().exists
    }

    func isActivityIndicatorExists() -> Bool {
        activityIndicator().exists
    }

    func isBackButtonExists() -> Bool {
        backButton().exists
    }

    func isImageViewVisible() -> Bool {
        imageView().exists && imageView().isHittable
    }

    func isChromeVisible() -> Bool {
        backButton().isHittable && shareButton().isHittable && fullscreenButton().isHittable && pageControl().isHittable
    }

    func isChromeHidden() -> Bool {
        !backButton().isHittable && !shareButton().isHittable && !fullscreenButton().isHittable && !pageControl().isHittable
    }

    func pageProgress() -> (current: Int, total: Int)? {
        guard pageControl().exists else { return nil }
        let rawValue: String
        if let value = pageControl().value as? String, !value.isEmpty {
            rawValue = value
        } else {
            rawValue = pageControl().label
        }
        let components = rawValue.split { !$0.isNumber }.compactMap { Int($0) }
        guard components.count >= 2 else { return nil }
        return (components[0], components[1])
    }

    func retryButton() -> XCUIElement {
        app.buttons[Identifiers.retryButton]
    }

    func waitForRetryButton(timeout: TimeInterval = 5) -> XCUIElement {
        let button = retryButton()
        XCTAssertTrue(button.waitForExistence(timeout: timeout))
        return button
    }
}

private extension ImageViewerViewRobot {
    enum Identifiers {
        static let collectionView = "image-viewer-collection"
        static let backButton = "image-viewer-back-button"
        static let shareButton = "image-viewer-share-button"
        static let fullscreenButton = "image-viewer-fullscreen-button"
        static let pageControl = "image-viewer-page-control"
        static let imageView = "image-viewer-image"
        static let activityIndicator = "image-viewer-activity"
        static let shareSheet = "ActivityListView"
        static let retryButton = "image-viewer-retry"
    }

    func collectionView() -> XCUIElement {
        app.collectionViews[Identifiers.collectionView]
    }

    func backButton() -> XCUIElement {
        let button = app.buttons[Identifiers.backButton]
        if button.exists {
            return button
        }
        return app.otherElements[Identifiers.backButton]
    }

    func shareButton() -> XCUIElement {
        let button = app.buttons[Identifiers.shareButton]
        if button.exists {
            return button
        }
        return app.otherElements[Identifiers.shareButton]
    }

    func fullscreenButton() -> XCUIElement {
        let button = app.buttons[Identifiers.fullscreenButton]
        if button.exists {
            return button
        }
        return app.otherElements[Identifiers.fullscreenButton]
    }

    func pageControl() -> XCUIElement {
        let control = app.pageIndicators[Identifiers.pageControl]
        if control.exists {
            return control
        }
        return app.otherElements[Identifiers.pageControl]
    }

    func imageView() -> XCUIElement {
        let image = app.images[Identifiers.imageView]
        if image.exists {
            return image
        }
        return app.images.element(boundBy: 0)
    }

    func activityIndicator() -> XCUIElement {
        let indicator = app.activityIndicators[Identifiers.activityIndicator]
        if indicator.exists {
            return indicator
        }
        return app.activityIndicators.element(boundBy: 0)
    }

    func shareSheet() -> XCUIElement {
        let element = app.otherElements[Identifiers.shareSheet]
        if element.exists {
            return element
        }
        return app.collectionViews[Identifiers.shareSheet]
    }
}

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
    func waitForChromeVisible(timeout: TimeInterval = 6) -> Self {
        assertChromeState(isHidden: false, timeout: timeout)
        return self
    }

    @discardableResult
    func waitForChromeHidden(timeout: TimeInterval = 6) -> Self {
        assertChromeState(isHidden: true, timeout: timeout)
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
    func waitForShareSheet(timeout: TimeInterval = 6) -> Self {
        let sheet = shareSheet()
        XCTAssertTrue(sheet.waitForExistence(timeout: timeout))
        return self
    }

    @discardableResult
    func waitForPage(index: Int, timeout: TimeInterval = 6) -> Self {
        let predicate = NSPredicate { _, _ in
            self.pageProgress()?.current == index
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: pageControl())
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed)
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
        isElementVisible(imageView())
    }

    func isChromeVisible() -> Bool {
        chromeElements().allSatisfy { isElementVisible($0) }
    }

    func isChromeHidden() -> Bool {
        chromeElements().allSatisfy { !isElementVisible($0) }
    }

    func pageProgress() -> (current: Int, total: Int)? {
        guard pageControl().exists else { return nil }
        let rawValue = (pageControl().value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? pageControl().label
        let numbers = rawValue.split { !$0.isNumber }.compactMap { Int($0) }
        guard numbers.count >= 2 else { return nil }
        return (numbers[0], numbers[1])
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
        let identified = app.images[Identifiers.imageView]
        if identified.exists {
            return identified
        }
        let collectionImage = collectionView().images[Identifiers.imageView]
        if collectionImage.exists {
            return collectionImage
        }
        let firstVisible = collectionView().images.element(boundBy: 0)
        if firstVisible.exists {
            return firstVisible
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
        let modernShare = app.otherElements["com.apple.UIKit.activity-group-view"]
        if modernShare.exists && modernShare.isHittable {
            return modernShare
        }
        let element = app.otherElements[Identifiers.shareSheet]
        if element.exists {
            return element
        }
        let collection = app.collectionViews[Identifiers.shareSheet]
        if collection.exists {
            return collection
        }
        let sheet = app.sheets.firstMatch
        if sheet.exists {
            return sheet
        }
        let fallback = app.otherElements["UIActivityContentView"]
        if fallback.exists {
            return fallback
        }
        return app.otherElements.firstMatch
    }

    func chromeElements() -> [XCUIElement] {
        [backButton(), shareButton(), fullscreenButton(), pageControl()]
    }

    func assertChromeState(isHidden: Bool, timeout: TimeInterval) {
        chromeElements().forEach { element in
            XCTAssertTrue(element.waitForExistence(timeout: timeout))
            let predicate = NSPredicate { _, _ in
                self.isElementVisible(element) == !isHidden
            }
            let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed)
        }
    }

    func isElementVisible(_ element: XCUIElement) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        guard frame != .zero else { return false }
        let windowFrame = app.windows.firstMatch.frame
        return windowFrame.intersects(frame)
    }
}

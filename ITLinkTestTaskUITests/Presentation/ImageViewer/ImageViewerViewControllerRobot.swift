import XCTest

final class ImageViewerViewRobot {
    private let app: XCUIApplication
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    @discardableResult
    func waitForImageView(timeout: TimeInterval = 10) -> Self {
        let imageView = app.images.element(boundBy: 0)
        XCTAssertTrue(imageView.waitForExistence(timeout: timeout))
        return self
    }
    
    @discardableResult
    func waitForActivityIndicator(timeout: TimeInterval = 10) -> Self {
        let activityIndicator = app.activityIndicators.element(boundBy: 0)
        XCTAssertTrue(activityIndicator.waitForExistence(timeout: timeout))
        return self
    }
    
    @discardableResult
    func waitForBackButton(timeout: TimeInterval = 10) -> Self {
        XCTAssertTrue(backButton().waitForExistence(timeout: timeout))
        return self
    }
    
    @discardableResult
    func tapBackButton() -> Self {
        backButton().tap()
        return self
    }
    
    @discardableResult
    func tapImageView() -> Self {
        let imageView = app.images.element(boundBy: 0)
        imageView.tap()
        return self
    }
    
    @discardableResult
    func pinchImageView(scale: CGFloat) -> Self {
        let imageView = app.images.element(boundBy: 0)
        imageView.pinch(withScale: scale, velocity: 1.0)
        return self
    }
    
    @discardableResult
    func swipeLeft() -> Self {
        let imageView = app.images.element(boundBy: 0)
        imageView.swipeLeft()
        return self
    }
    
    @discardableResult
    func swipeRight() -> Self {
        let imageView = app.images.element(boundBy: 0)
        imageView.swipeRight()
        return self
    }
    
    func isImageViewExists() -> Bool {
        return app.images.element(boundBy: 0).exists
    }
    
    func isActivityIndicatorExists() -> Bool {
        return app.activityIndicators.element(boundBy: 0).exists
    }
    
    func isBackButtonExists() -> Bool {
        return backButton().exists
    }
    
    func isImageViewVisible() -> Bool {
        let imageView = app.images.element(boundBy: 0)
        return imageView.exists && imageView.isHittable
    }
}

private extension ImageViewerViewRobot {
    enum Identifiers {
        static let backButton = "image-viewer-back-button"
    }

    func backButton() -> XCUIElement {
        let button = app.buttons[Identifiers.backButton]
        if button.exists {
            return button
        }
        return app.otherElements[Identifiers.backButton]
    }
}

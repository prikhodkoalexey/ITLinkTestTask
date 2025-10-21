import CoreGraphics
import XCTest

struct GalleryViewRobot {
    private let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    @discardableResult
    func waitForGrid(timeout: TimeInterval = 5) -> Self {
        let cell = app.collectionViews.cells[Identifiers.galleryCell]
        _ = cell.waitForExistence(timeout: timeout)
        return self
    }

    @discardableResult
    func pullToRefresh() -> Self {
        let collection = app.collectionViews.element
        if collection.waitForExistence(timeout: 1) {
            let start = collection.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            let finish = collection.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            start.press(forDuration: 0.01, thenDragTo: finish)
        }
        return self
    }

    @discardableResult
    func tapFirstImage(file: StaticString = #file, line: UInt = #line) -> Self {
        let firstCell = app.collectionViews.cells.matching(identifier: Identifiers.galleryCell).element(boundBy: 0)
        guard firstCell.waitForExistence(timeout: 5) else {
            XCTFail("First gallery cell not found", file: file, line: line)
            return self
        }
        let coordinate = firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        coordinate.tap()
        return self
    }

    @discardableResult
    func tapRetry(file: StaticString = #file, line: UInt = #line) -> Self {
        let button = app.buttons[Identifiers.retryButton]
        guard button.waitForExistence(timeout: 5) else {
            XCTFail("Retry button not found", file: file, line: line)
            return self
        }
        button.tap()
        return self
    }

    func cell(at index: Int) -> XCUIElement {
        app.collectionViews.cells.matching(identifier: Identifiers.galleryCell).element(boundBy: index)
    }

    func placeholder(at index: Int) -> XCUIElement {
        app.collectionViews.cells.matching(identifier: Identifiers.placeholderCell).element(boundBy: index)
    }

    func errorLabel() -> XCUIElement {
        app.staticTexts[Identifiers.errorLabel]
    }

    enum Identifiers {
        static let galleryCell = "gallery-cell"
        static let placeholderCell = "gallery-placeholder"
        static let retryButton = "gallery-retry-button"
        static let errorLabel = "gallery-error-label"
    }
}

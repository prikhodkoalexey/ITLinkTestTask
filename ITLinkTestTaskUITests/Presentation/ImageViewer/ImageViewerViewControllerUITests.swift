import XCTest

final class ImageViewerViewControllerUITests: XCTestCase {
    private var app: XCUIApplication!
    private var robot: ImageViewerViewRobot!
    private var baseArguments: [String] = []
    private var baseEnvironment: [String: String] = [:]
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        baseArguments = ["UIPRESENTATION_TESTING", "--gallery"]
        baseEnvironment = [
            "UITESTING": "1",
            "UITEST_GALLERY_MODE": "stub"
        ]
        robot = ImageViewerViewRobot(app: app)
    }
    
    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
        robot = nil
        baseArguments = []
        baseEnvironment = [:]
    }
    
    func testImageViewerDisplaysImage() {
        launch()
        robot.waitForImageView()
        XCTAssertTrue(robot.isImageViewVisible())
    }
    
    func testImageViewerShowsLoadingIndicatorWhileLoading() {
        launch()
        robot.waitForActivityIndicator()
        XCTAssertTrue(robot.isActivityIndicatorExists())
    }
    
    func testImageViewerHasBackButton() {
        launch()
        robot.waitForBackButton()
        XCTAssertTrue(robot.isBackButtonExists())
    }
    
    func testImageViewerBackButtonReturnsToGallery() {
        launch()
        robot.waitForBackButton()
        robot.tapBackButton()
        XCTAssertTrue(app.collectionViews.element.exists)
    }
    
    func testImageViewerSupportsZoom() {
        launch()
        robot.waitForImageView()
        robot.pinchImageView(scale: 2.0)
        XCTAssertTrue(robot.isImageViewVisible())
    }
    
    func testImageViewerSupportsSwiping() {
        launch()
        robot.waitForImageView()
        robot.swipeLeft()
        XCTAssertTrue(robot.isImageViewVisible())
        robot.swipeRight()
        XCTAssertTrue(robot.isImageViewVisible())
    }
    
    private func launch() {
        app.launchArguments = baseArguments
        app.launchEnvironment = baseEnvironment
        app.launch()
    }
}
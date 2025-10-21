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
        robot = nil
    }
    
    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
        robot = nil
        baseArguments = []
        baseEnvironment = [:]
    }

    func testInitialPageShowsChromeAndProgress() throws {
        launch()
        robot.waitForChromeVisible()
        let progress = try XCTUnwrap(robot.pageProgress())
        XCTAssertEqual(progress.current, 1)
        XCTAssertEqual(progress.total, 3)
    }

    func testSwipingChangesPages() {
        launch()
        robot.waitForPage(index: 1)
        robot.swipeLeft().waitForPage(index: 2)
        robot.swipeLeft().waitForPage(index: 3)
        robot.swipeRight().waitForPage(index: 2)
    }

    func testSingleTapTogglesChrome() {
        launch()
        robot.waitForChromeVisible()
        robot.tapImageView().waitForChromeHidden()
        robot.tapImageView().waitForChromeVisible()
    }

    func testFullscreenButtonTogglesChrome() {
        launch()
        robot.waitForChromeVisible()
        robot.tapFullscreenButton().waitForChromeHidden()
        robot.tapFullscreenButton().waitForChromeVisible()
    }

    func testShareButtonPresentsShareSheet() {
        launch()
        robot.tapShareButton().waitForShareSheet()
        XCTAssertTrue(robot.isShareSheetPresented())
    }

    func testBackButtonReturnsToGallery() {
        launch()
        robot.waitForBackButton()
        robot.tapBackButton()
        XCTAssertTrue(app.collectionViews.element.waitForExistence(timeout: 5))
    }

    func testZoomGesturesKeepImageVisible() {
        launch()
        robot.waitForViewer()
        robot.pinchImageView(scale: 2.0)
        XCTAssertTrue(robot.isImageViewVisible())
        robot.doubleTapImageView()
        XCTAssertTrue(robot.isImageViewVisible())
        robot.doubleTapImageView()
        XCTAssertTrue(robot.isImageViewVisible())
    }

    private func launch(additionalEnvironment: [String: String] = [:]) {
        var environment = baseEnvironment
        additionalEnvironment.forEach { key, value in
            environment[key] = value
        }
        app.launchArguments = baseArguments
        app.launchEnvironment = environment
        app.launch()
        GalleryViewRobot(app: app)
            .waitForGrid()
            .tapFirstImage()
        robot = ImageViewerViewRobot(app: app)
            .waitForViewer()
    }
}

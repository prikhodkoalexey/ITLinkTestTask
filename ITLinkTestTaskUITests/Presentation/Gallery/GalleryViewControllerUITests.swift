import XCTest

final class GalleryViewControllerUITests: XCTestCase {
    private var app: XCUIApplication!
    private var robot: GalleryViewRobot!
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
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
        robot = nil
        baseArguments = []
        baseEnvironment = [:]
    }

    func testInitialLoadDisplaysGrid() {
        launch()
        robot.waitForGrid()
        XCTAssertTrue(robot.cell(at: 0).exists)
    }

    func testPullToRefreshKeepsContentVisible() {
        launch()
        robot.waitForGrid().pullToRefresh().waitForGrid()
        XCTAssertTrue(robot.cell(at: 0).exists)
    }

    func testRetryRestoresGridAfterTransientFailure() {
        launch(additionalArguments: ["--force-network-error-once"])
        XCTAssertTrue(robot.errorLabel().waitForExistence(timeout: 5))
        robot.tapRetry().waitForGrid()
        XCTAssertTrue(robot.cell(at: 0).exists)
    }

    func testRetryButtonAppearsWhenFailurePersists() {
        launch(additionalArguments: ["--force-network-error"])
        XCTAssertTrue(robot.errorLabel().waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[GalleryViewRobot.Identifiers.retryButton].exists)
    }

    func testThumbnailRetryRecoversPreview() {
        launch(
            additionalEnvironment: [
                "UITEST_THUMBNAIL_FAILURE": "once"
            ]
        )
        robot.waitForGrid()
        let retryButton = robot.thumbnailRetryButton(at: 0)
        XCTAssertTrue(retryButton.waitForExistence(timeout: 5))
        robot.tapThumbnailRetry(at: 0)
        XCTAssertFalse(retryButton.waitForExistence(timeout: 5))
    }

    private func launch(
        additionalArguments: [String] = [],
        additionalEnvironment: [String: String] = [:]
    ) {
        var environment = baseEnvironment
        if additionalArguments.contains("--force-network-error") {
            environment["UITEST_FAILURE_MODE"] = "always"
            environment["UITEST_FAILURE_SEQUENCE"] = "fail,fail"
        } else if additionalArguments.contains("--force-network-error-once") {
            environment["UITEST_FAILURE_MODE"] = "once"
            environment["UITEST_FAILURE_SEQUENCE"] = "fail,success"
        } else {
            environment["UITEST_FAILURE_MODE"] = nil
            environment["UITEST_FAILURE_SEQUENCE"] = nil
        }
        additionalEnvironment.forEach { key, value in
            environment[key] = value
        }
        app.launchEnvironment = environment
        app.launchArguments = baseArguments + additionalArguments
        app.launch()
        robot = GalleryViewRobot(app: app)
    }
}

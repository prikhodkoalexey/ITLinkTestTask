import Foundation
import XCTest
@testable import ITLinkTestTask

final class FileNameHasherTests: XCTestCase {
    func testProducesHexNameWithoutExtension() {
        let hasher = SHA256FileNameHasher()
        let name = hasher.makeFileName(for: "abc", fileExtension: nil)
        XCTAssertEqual(name.count, 64)
        XCTAssertFalse(name.contains("."))
    }

    func testAppendsSanitizedExtension() {
        let hasher = SHA256FileNameHasher()
        let name = hasher.makeFileName(for: "abc", fileExtension: ".png")
        XCTAssertTrue(name.hasSuffix(".png"))
    }
}

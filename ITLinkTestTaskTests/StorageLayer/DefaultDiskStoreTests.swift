import Foundation
import XCTest
@testable import ITLinkTestTask

final class DefaultDiskStoreTests: XCTestCase {
    func testCreatesNamespaceDirectories() throws {
        let temp = makeTempDirectory()
        defer { removeTempDirectory(temp) }
        let store = try DefaultDiskStore(fileManager: .default, baseURL: temp)
        for namespace in DiskStoreNamespace.allCases {
            let url = try store.directoryURL(for: namespace)
            var isDir: ObjCBool = false
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir))
            XCTAssertTrue(isDir.boolValue)
        }
    }

    func testProvidesFileURLInNamespace() throws {
        let temp = makeTempDirectory()
        defer { removeTempDirectory(temp) }
        let store = try DefaultDiskStore(fileManager: .default, baseURL: temp)
        let fileURL = try store.fileURL(in: .links, fileName: "test.bin")
        XCTAssertTrue(fileURL.path.hasSuffix("links/test.bin"))
    }

    private func makeTempDirectory() -> URL {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        return temp
    }

    private func removeTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

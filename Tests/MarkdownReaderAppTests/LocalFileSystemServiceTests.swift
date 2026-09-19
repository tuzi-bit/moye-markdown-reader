import Foundation
import XCTest
@testable import MarkdownReaderApp

final class LocalFileSystemServiceTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MarkdownReaderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testTreeIncludesMarkdownAndFoldersButSkipsOtherFiles() throws {
        let nested = temporaryDirectory.appendingPathComponent("Notes", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: false)
        try "# Hello".write(to: temporaryDirectory.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try "ignore".write(to: temporaryDirectory.appendingPathComponent("ignore.txt"), atomically: true, encoding: .utf8)
        try "# Nested".write(to: nested.appendingPathComponent("nested.markdown"), atomically: true, encoding: .utf8)

        let nodes = try LocalFileSystemService().tree(for: temporaryDirectory)

        XCTAssertEqual(nodes.map(\.name), ["Notes", "README.md"])
        XCTAssertEqual(nodes.first?.children.map(\.name), ["nested.markdown"])
    }

    func testReadMarkdownReturnsSourceAndMetadata() throws {
        let url = temporaryDirectory.appendingPathComponent("Readme.md")
        try "# Title\n\nBody".write(to: url, atomically: true, encoding: .utf8)

        let document = try LocalFileSystemService().readMarkdown(at: url)

        XCTAssertEqual(document.title, "Readme")
        XCTAssertEqual(document.source, "# Title\n\nBody")
        XCTAssertNotNil(document.modifiedAt)
    }

    func testCreateFileRejectsExistingPath() throws {
        let url = temporaryDirectory.appendingPathComponent("same.md")
        try "first".write(to: url, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try LocalFileSystemService().createFile(at: url, contents: "second")) { error in
            XCTAssertEqual(error as? FileSystemError, .itemAlreadyExists(url))
        }
    }

    func testWriteMarkdownPersistsUpdatedSource() throws {
        let url = temporaryDirectory.appendingPathComponent("editable.md")
        try "# Before".write(to: url, atomically: true, encoding: .utf8)

        try LocalFileSystemService().writeMarkdown(at: url, contents: "# After")

        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "# After")
    }

    func testRenameMarkdownMovesFileAndKeepsContents() throws {
        let sourceURL = temporaryDirectory.appendingPathComponent("before.md")
        let destinationURL = temporaryDirectory.appendingPathComponent("after.md")
        try "# Rename me".write(to: sourceURL, atomically: true, encoding: .utf8)

        try LocalFileSystemService().renameMarkdown(at: sourceURL, to: destinationURL)

        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertEqual(try String(contentsOf: destinationURL, encoding: .utf8), "# Rename me")
    }
}

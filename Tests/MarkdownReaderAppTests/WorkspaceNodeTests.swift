import Foundation
import XCTest
@testable import MarkdownReaderApp

final class WorkspaceNodeTests: XCTestCase {
    func testMarkdownExtensionsAreCaseInsensitive() {
        XCTAssertTrue(DocumentSupport.isMarkdownFile(URL(fileURLWithPath: "/tmp/README.MD")))
        XCTAssertTrue(DocumentSupport.isMarkdownFile(URL(fileURLWithPath: "/tmp/notes.markdown")))
        XCTAssertFalse(DocumentSupport.isMarkdownFile(URL(fileURLWithPath: "/tmp/notes.txt")))
    }

    func testFilteringKeepsMatchingParentFolders() {
        let document = WorkspaceNode(
            url: URL(fileURLWithPath: "/tmp/guide.md"),
            kind: .markdownFile,
            children: []
        )
        let folder = WorkspaceNode(
            url: URL(fileURLWithPath: "/tmp/Manual"),
            kind: .folder,
            children: [document]
        )

        XCTAssertEqual(folder.filtered(matching: "guide")?.children.count, 1)
        XCTAssertNil(folder.filtered(matching: "missing"))
    }

    func testDescendantCheckDoesNotAcceptSiblingPrefix() {
        let root = URL(fileURLWithPath: "/tmp/docs")
        XCTAssertTrue(URL(fileURLWithPath: "/tmp/docs/readme.md").isDescendant(of: root))
        XCTAssertFalse(URL(fileURLWithPath: "/tmp/docs-backup/readme.md").isDescendant(of: root))
        XCTAssertFalse(root.isDescendant(of: root))
    }

    func testWorkspaceExclusionsPersistWithoutTouchingTheFile() throws {
        let suiteName = "MarkdownReaderTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = UserDefaultsWorkspaceExclusionStore(defaults: defaults)
        let workspace = URL(fileURLWithPath: "/tmp/docs")
        let document = workspace.appendingPathComponent("readme.md")

        store.saveExcludedURLs([document], for: workspace)

        XCTAssertEqual(store.excludedURLs(for: workspace), [document])
    }

    func testNewDocumentLocationDefaultsToDocumentsWorkspace() {
        let provider = DocumentsNewDocumentLocationProvider()
        let url = provider.defaultWorkspaceURL()

        XCTAssertEqual(url.lastPathComponent, "Markdown Reader")
        XCTAssertTrue(url.path.contains("Documents"))
    }
}

import XCTest
@testable import MarkdownReaderApp

final class MarkdownTableEditorTests: XCTestCase {
    private let editor = MarkdownTableEditor()

    func testReadsAndRewritesFirstTable() {
        let source = """
        # Data

        | Name | Result |
        | --- | --- |
        | Build | Pass |
        """
        let session = try! XCTUnwrap(editor.firstTable(in: source))
        XCTAssertEqual(session.headers, ["Name", "Result"])
        XCTAssertEqual(session.rows, [["Build", "Pass"]])

        var updated = session
        updated.headers[1] = "Status"
        updated.rows.append(["Test", "Pass"])
        let result = editor.replacingFirstTable(in: source, with: updated)

        XCTAssertTrue(result.contains("| Name | Status |"))
        XCTAssertTrue(result.contains("| Test | Pass |"))
    }

    func testReturnsNilWhenSourceHasNoTable() {
        XCTAssertNil(editor.firstTable(in: "# No table\n\nText"))
    }
}

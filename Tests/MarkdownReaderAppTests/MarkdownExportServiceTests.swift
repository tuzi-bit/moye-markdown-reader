import XCTest
@testable import MarkdownReaderApp

final class MarkdownExportServiceTests: XCTestCase {
    func testHTMLExportPreservesCommonMarkdownBlocksAndEscapesHTML() {
        let source = """
        # Title

        **Important** and `code`.

        - [x] Done
        - [ ] Next

        <unsafe>
        """

        let html = MarkdownExportService().html(for: source, title: "My <Document>")

        XCTAssertTrue(html.contains("<title>My &lt;Document&gt;</title>"))
        XCTAssertTrue(html.contains("<h1>Title</h1>"))
        XCTAssertTrue(html.contains("<strong>Important</strong>"))
        XCTAssertTrue(html.contains("<code>code</code>"))
        XCTAssertTrue(html.contains("class=\"task-list\""))
        XCTAssertTrue(html.contains("checked"))
        XCTAssertTrue(html.contains("&lt;unsafe&gt;"))
        XCTAssertFalse(html.contains("<unsafe>"))
    }

    func testHTMLExportResolvesRelativeStandaloneImageAgainstDocumentFolder() {
        let baseURL = URL(fileURLWithPath: "/tmp/markdown-docs")
        let html = MarkdownExportService().html(
            for: "![Diagram](assets/diagram.png)",
            title: "Images",
            baseURL: baseURL
        )

        XCTAssertTrue(html.contains("file:///tmp/markdown-docs/assets/diagram.png"))
    }
}

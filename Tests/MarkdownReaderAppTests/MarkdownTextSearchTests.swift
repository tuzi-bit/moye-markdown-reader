import XCTest
@testable import MarkdownReaderApp

final class MarkdownTextSearchTests: XCTestCase {
    private let search = MarkdownTextSearch()

    func testMatchCountIsCaseInsensitive() {
        XCTAssertEqual(search.matchCount(in: "Hello hello HELLO", query: "hello"), 3)
        XCTAssertEqual(search.matchCount(in: "No match", query: ""), 0)
    }

    func testReplacingFirstOnlyChangesTheFirstMatch() {
        let result = search.replacingFirst(
            in: "Title\nTitle",
            query: "title",
            with: "Heading"
        )

        XCTAssertEqual(result, "Heading\nTitle")
    }

    func testReplacingAllSupportsEmptyReplacement() {
        let result = search.replacingAll(
            in: "draft draft Draft",
            query: "draft",
            with: ""
        )

        XCTAssertEqual(result, "  ")
    }
}

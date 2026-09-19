import XCTest
@testable import MarkdownReaderApp

final class MarkdownRendererTests: XCTestCase {
    func testRendererPreservesMarkdownText() {
        let rendered = MarkdownRenderer().render("# Hello\n\nThis is **important**.")
        XCTAssertTrue(String(rendered.characters).contains("Hello"))
        XCTAssertTrue(String(rendered.characters).contains("important"))
    }

    func testRendererBuildsBlocksForHeadingsListsTablesAndCode() {
        let fence = String(repeating: Character(UnicodeScalar(96)!), count: 3)
        let source = """
        # Title

        - One
        - Two

        | Name | Result |
        | --- | --- |
        | Build | Pass |

        \(fence)swift
        let value = 1
        \(fence)
        """

        let blocks = MarkdownRenderer().blocks(from: source)

        XCTAssertEqual(blocks.count, 4)
        if case let .heading(level, text) = blocks[0].kind {
            XCTAssertEqual(level, 1)
            XCTAssertEqual(text, "Title")
        } else {
            XCTFail("Expected a heading block")
        }
        if case let .unorderedList(items) = blocks[1].kind {
            XCTAssertEqual(items, ["One", "Two"])
        } else {
            XCTFail("Expected an unordered list block")
        }
        if case let .table(headers, rows) = blocks[2].kind {
            XCTAssertEqual(headers, ["Name", "Result"])
            XCTAssertEqual(rows, [["Build", "Pass"]])
        } else {
            XCTFail("Expected a table block")
        }
        if case let .code(language, text) = blocks[3].kind {
            XCTAssertEqual(language, "swift")
            XCTAssertEqual(text, "let value = 1")
        } else {
            XCTFail("Expected a code block")
        }
    }

    func testRendererBuildsTaskListAndStandaloneImage() {
        let source = """
        - [x] Finished
        - [ ] Next

        ![A diagram](assets/diagram.png)
        """

        let blocks = MarkdownRenderer().blocks(from: source)

        XCTAssertEqual(blocks.count, 2)
        if case let .taskList(items) = blocks[0].kind {
            XCTAssertEqual(items.map(\.text), ["Finished", "Next"])
            XCTAssertEqual(items.map(\.isChecked), [true, false])
        } else {
            XCTFail("Expected a task list block")
        }
        if case let .image(image) = blocks[1].kind {
            XCTAssertEqual(image.altText, "A diagram")
            XCTAssertEqual(image.source, "assets/diagram.png")
        } else {
            XCTFail("Expected an image block")
        }
    }

    func testRendererBuildsHeadingOutlineWithBlockIDs() {
        let source = """
        # Introduction

        ## Installation

        ### Troubleshooting
        """

        let outline = MarkdownRenderer().outline(from: source)

        XCTAssertEqual(outline.map(\.title), ["Introduction", "Installation", "Troubleshooting"])
        XCTAssertEqual(outline.map(\.level), [1, 2, 3])
        XCTAssertEqual(outline.map(\.blockID), [0, 1, 2])
    }

    func testRendererBuildsMathAndMermaidBlocks() {
        let fence = String(repeating: Character(UnicodeScalar(96)!), count: 3)
        let source = """
        $$a^2 + b^2 = c^2$$

        \(fence)mermaid
        flowchart LR
        A[Start] --> B[Finish]
        \(fence)
        """

        let blocks = MarkdownRenderer().blocks(from: source)

        XCTAssertEqual(blocks.count, 2)
        if case let .math(expression) = blocks[0].kind {
            XCTAssertEqual(expression, "a^2 + b^2 = c^2")
        } else {
            XCTFail("Expected a math block")
        }
        if case let .mermaid(diagram) = blocks[1].kind {
            XCTAssertTrue(diagram.contains("A[Start]"))
        } else {
            XCTFail("Expected a Mermaid block")
        }
    }
}

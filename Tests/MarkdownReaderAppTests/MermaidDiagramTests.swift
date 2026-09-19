import XCTest
@testable import MarkdownReaderApp

final class MermaidDiagramTests: XCTestCase {
    func testParsesSimpleHorizontalFlowchart() {
        let diagram = MermaidDiagram.parse("""
        flowchart LR
        A[Start] --> B[Finish]
        """)

        XCTAssertEqual(diagram?.direction, .horizontal)
        XCTAssertEqual(diagram?.nodes.map(\.label), ["Start", "Finish"])
    }

    func testReturnsNilForUnsupportedDiagramSource() {
        XCTAssertNil(MermaidDiagram.parse("sequenceDiagram\nAlice->>Bob: Hello"))
    }
}

import XCTest
@testable import MarkdownReaderApp

final class MathExpressionRendererTests: XCTestCase {
    private let renderer = MathExpressionRenderer()

    func testRendersCommonLatexSymbolsAndSuperscripts() {
        XCTAssertEqual(
            renderer.displayText(for: "a^2 + b^2 = c^2"),
            "a² + b² = c²"
        )
        XCTAssertEqual(renderer.displayText(for: "\\alpha + \\beta"), "α + β")
    }

    func testRendersFractionsAsReadableText() {
        XCTAssertEqual(renderer.displayText(for: "\\frac{a}{b}"), "(a⁄b)")
    }
}

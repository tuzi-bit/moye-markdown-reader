import AppKit
import Foundation

enum MarkdownFormatting {
    static func styledEditorText(_ source: String) -> NSAttributedString {
        let result = NSMutableAttributedString(
            string: source,
            attributes: [
                .font: NSFont.systemFont(ofSize: 17),
                .foregroundColor: NSColor.labelColor
            ]
        )

        let fullRange = NSRange(location: 0, length: (source as NSString).length)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5
        paragraphStyle.paragraphSpacing = 10
        result.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)

        applyHeadings(to: result, source: source)
        applyBlockQuotes(to: result, source: source)
        applyFencedCode(to: result, source: source)
        applyInlineCode(to: result, source: source)
        applyStrong(to: result, source: source)
        applyEmphasis(to: result, source: source)
        applyStrikethrough(to: result, source: source)
        applyTaskItems(to: result, source: source)
        applyLinks(to: result, source: source)
        return result
    }

    private static func applyHeadings(to result: NSMutableAttributedString, source: String) {
        let pattern = #"(?m)^(#{1,6})[ \t]+(.+?)(?=\r?$)"#
        for match in matches(pattern, in: source) {
            let marker = match.range(at: 1)
            let title = match.range(at: 2)
            let hiddenPrefixLength = title.location - match.range.location
            result.addAttribute(
                .foregroundColor,
                value: NSColor.clear,
                range: NSRange(location: match.range.location, length: hiddenPrefixLength)
            )
            let size = max(18, 30 - CGFloat(marker.length * 2))
            result.addAttribute(
                .font,
                value: NSFont.systemFont(ofSize: size, weight: .bold),
                range: title
            )
        }
    }

    private static func applyBlockQuotes(to result: NSMutableAttributedString, source: String) {
        let pattern = #"(?m)^(\s*>[ \t]?)(.+?)(?=\r?$)"#
        for match in matches(pattern, in: source) {
            let prefix = match.range(at: 1)
            let content = match.range(at: 2)
            result.addAttribute(.foregroundColor, value: NSColor.clear, range: prefix)
            result.addAttributes([
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: NSFontManager.shared.convert(
                    NSFont.systemFont(ofSize: 17),
                    toHaveTrait: .italicFontMask
                )
            ], range: content)
        }
    }

    private static func applyFencedCode(to result: NSMutableAttributedString, source: String) {
        let pattern = #"(?ms)^\s*(`{3,}[^\n]*\n)(.*?)(?:\n\s*`{3,})(?=\r?$)"#
        for match in matches(pattern, in: source) {
            let opening = match.range(at: 1)
            let content = match.range(at: 2)
            result.addAttribute(.foregroundColor, value: NSColor.clear, range: opening)
            result.addAttributes([
                .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .regular),
                .backgroundColor: NSColor.controlBackgroundColor
            ], range: content)
            let closingStart = NSMaxRange(content)
            let closingLength = NSMaxRange(match.range) - closingStart
            if closingLength > 0 {
                result.addAttribute(
                    .foregroundColor,
                    value: NSColor.clear,
                    range: NSRange(location: closingStart, length: closingLength)
                )
            }
        }
    }

    private static func applyInlineCode(to result: NSMutableAttributedString, source: String) {
        for match in matches(#"`([^`\n]+)`"#, in: source) {
            let content = match.range(at: 1)
            hideDelimiters(of: match.range, content: content, in: result)
            result.addAttributes([
                .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .regular),
                .backgroundColor: NSColor.controlBackgroundColor
            ], range: content)
        }
    }

    private static func applyStrong(to result: NSMutableAttributedString, source: String) {
        for match in matches(#"\*\*([^*\n]+)\*\*|__([^_\n]+)__"#, in: source) {
            let content = match.range(at: 1).location != NSNotFound ? match.range(at: 1) : match.range(at: 2)
            hideDelimiters(of: match.range, content: content, in: result)
            result.addAttribute(
                .font,
                value: NSFont.systemFont(ofSize: 17, weight: .bold),
                range: content
            )
        }
    }

    private static func applyEmphasis(to result: NSMutableAttributedString, source: String) {
        for match in matches(#"(?<!\*)\*([^*\n]+)\*(?!\*)|(?<!_)_([^_\n]+)_(?!_)"#, in: source) {
            let content = match.range(at: 1).location != NSNotFound ? match.range(at: 1) : match.range(at: 2)
            hideDelimiters(of: match.range, content: content, in: result)
            result.addAttribute(
                .font,
                value: NSFontManager.shared.convert(NSFont.systemFont(ofSize: 17), toHaveTrait: .italicFontMask),
                range: content
            )
        }
    }

    private static func applyStrikethrough(to result: NSMutableAttributedString, source: String) {
        for match in matches(#"~~([^~\n]+)~~"#, in: source) {
            let content = match.range(at: 1)
            hideDelimiters(of: match.range, content: content, in: result)
            result.addAttribute(
                .strikethroughStyle,
                value: NSUnderlineStyle.single.rawValue,
                range: content
            )
            result.addAttribute(
                .foregroundColor,
                value: NSColor.secondaryLabelColor,
                range: content
            )
        }
    }

    private static func applyTaskItems(to result: NSMutableAttributedString, source: String) {
        let pattern = #"(?m)^\s*(?:[-*+]|\d+[.)])\s+\[([ xX])\]\s+(.+?)(?=\r?$)"#
        for match in matches(pattern, in: source) {
            let marker = match.range(at: 1)
            let content = match.range(at: 2)
            let markerText = (source as NSString).substring(with: marker)
            guard markerText.lowercased() == "x" else {
                continue
            }
            result.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: content)
            result.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: content)
        }
    }

    private static func applyLinks(to result: NSMutableAttributedString, source: String) {
        for match in matches(#"\[([^\]]+)\]\(([^)]+)\)"#, in: source) {
            let label = match.range(at: 1)
            result.addAttribute(.foregroundColor, value: NSColor.clear, range: NSRange(location: match.range.location, length: label.location - match.range.location))
            let suffixStart = label.location + label.length
            result.addAttribute(.foregroundColor, value: NSColor.clear, range: NSRange(location: suffixStart, length: NSMaxRange(match.range) - suffixStart))
            result.addAttributes([
                .foregroundColor: NSColor.systemBlue,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ], range: label)
        }
    }

    private static func hideDelimiters(of match: NSRange, content: NSRange, in result: NSMutableAttributedString) {
        let prefixLength = content.location - match.location
        let suffixStart = content.location + content.length
        let suffixLength = NSMaxRange(match) - suffixStart
        if prefixLength > 0 {
            result.addAttribute(.foregroundColor, value: NSColor.clear, range: NSRange(location: match.location, length: prefixLength))
        }
        if suffixLength > 0 {
            result.addAttribute(.foregroundColor, value: NSColor.clear, range: NSRange(location: suffixStart, length: suffixLength))
        }
    }

    private static func matches(_ pattern: String, in source: String) -> [NSTextCheckingResult] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(location: 0, length: (source as NSString).length)
        return expression.matches(in: source, range: range)
    }
}

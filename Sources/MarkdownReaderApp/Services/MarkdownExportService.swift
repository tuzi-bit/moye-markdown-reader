import AppKit
import Foundation

struct MarkdownExportService {
    private let renderer = MarkdownRenderer()

    func html(
        for source: String,
        title: String,
        baseURL: URL? = nil
    ) -> String {
        let blocks = renderer.blocks(from: source)
        let body = blocks.map { html(for: $0.kind, baseURL: baseURL) }.joined(separator: "\n")
        return """
        <!doctype html>
        <html lang="zh-CN">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(escapeHTML(title))</title>
          <style>
            :root { color-scheme: light dark; }
            body { max-width: 920px; margin: 0 auto; padding: 48px 32px; color: #242424; background: #fff; font: 17px/1.75 -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif; }
            @media (prefers-color-scheme: dark) { body { color: #eee; background: #1e1e1e; } pre, code { background: #2c2c2e; } blockquote { border-color: #777; color: #bbb; } th { background: #333; } }
            h1, h2, h3, h4, h5, h6 { line-height: 1.3; margin: 1.4em 0 .55em; }
            h1 { font-size: 2.1em; } h2 { font-size: 1.7em; } h3 { font-size: 1.35em; }
            p { margin: 1em 0; } a { color: #1677ff; }
            blockquote { margin: 1em 0; padding-left: 1em; border-left: 4px solid #8ab4f8; color: #666; }
            pre, code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; background: #f3f3f3; border-radius: 6px; }
            pre { padding: 16px; overflow-x: auto; } pre code { background: none; }
            table { border-collapse: collapse; width: 100%; margin: 1em 0; } th, td { border: 1px solid #d5d5d5; padding: 8px 12px; text-align: left; vertical-align: top; } th { background: #f3f3f3; }
            img { max-width: 100%; height: auto; } figure { margin: 1em 0; } figcaption { color: #777; font-size: .9em; }
            .task-list { list-style: none; padding-left: 0; } .task-list input { margin-right: 8px; }
            hr { border: 0; border-top: 1px solid #d5d5d5; margin: 2em 0; }
          </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    func writeHTML(
        source: String,
        title: String,
        baseURL: URL?,
        to url: URL
    ) throws {
        do {
            try html(for: source, title: title, baseURL: baseURL)
                .write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw MarkdownExportError.writeFailed(url)
        }
    }

    @MainActor
    func printDocument(source: String) -> Bool {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 680, height: 100))
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.drawsBackground = true
        textView.backgroundColor = .white
        textView.textContainerInset = NSSize(width: 18, height: 18)
        textView.textStorage?.setAttributedString(MarkdownFormatting.styledEditorText(source))

        if let textContainer = textView.textContainer,
           let layoutManager = textView.layoutManager {
            textContainer.widthTracksTextView = false
            textContainer.containerSize = NSSize(width: 680, height: CGFloat.greatestFiniteMagnitude)
            layoutManager.ensureLayout(for: textContainer)
            let usedHeight = layoutManager.usedRect(for: textContainer).height
            textView.frame.size.height = max(100, usedHeight + 36)
        }

        let operation = NSPrintOperation(view: textView)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        return operation.run()
    }

    private func html(for kind: MarkdownBlock.Kind, baseURL: URL?) -> String {
        switch kind {
        case let .heading(level, text):
            return "<h\(level)>\(inlineHTML(text))</h\(level)>"
        case let .paragraph(text):
            return "<p>\(inlineHTML(text).replacingOccurrences(of: "\n", with: "<br>\n"))</p>"
        case let .unorderedList(items):
            return "<ul>\(items.map { "<li>\(inlineHTML($0))</li>" }.joined())</ul>"
        case let .orderedList(items):
            return "<ol>\(items.map { "<li>\(inlineHTML($0))</li>" }.joined())</ol>"
        case let .taskList(items):
            let list = items.map { item in
                let checked = item.isChecked ? " checked" : ""
                return "<li><input type=\"checkbox\" disabled\(checked)>\(inlineHTML(item.text))</li>"
            }.joined()
            return "<ul class=\"task-list\">\(list)</ul>"
        case let .quote(text):
            return "<blockquote>\(inlineHTML(text).replacingOccurrences(of: "\n", with: "<br>\n"))</blockquote>"
        case let .code(language, text):
            let className = language.map { " class=\"language-\(escapeHTML($0))\"" } ?? ""
            return "<pre><code\(className)>\(escapeHTML(text))</code></pre>"
        case let .math(expression):
            return "<div class=\"math-block\"><code>\(escapeHTML(expression))</code></div>"
        case let .mermaid(source):
            return "<pre class=\"mermaid\">\(escapeHTML(source))</pre>"
        case let .table(headers, rows):
            let header = headers.map { "<th>\(inlineHTML($0))</th>" }.joined()
            let body = rows.map { row in
                "<tr>\(row.map { "<td>\(inlineHTML($0))</td>" }.joined())</tr>"
            }.joined()
            return "<table><thead><tr>\(header)</tr></thead><tbody>\(body)</tbody></table>"
        case let .image(image):
            let source = imageSource(image.source, baseURL: baseURL)
            let caption = image.altText.isEmpty ? "" : "<figcaption>\(escapeHTML(image.altText))</figcaption>"
            return "<figure><img src=\"\(escapeHTML(source))\" alt=\"\(escapeHTML(image.altText))\">\(caption)</figure>"
        case .divider:
            return "<hr>"
        }
    }

    private func inlineHTML(_ source: String) -> String {
        var value = escapeHTML(source)
        value = replace(#"!\[([^\]]*)\]\(([^)]+)\)"#, in: value, with: "<img alt=\"$1\" src=\"$2\">")
        value = replace(#"\[([^\]]+)\]\(([^)]+)\)"#, in: value, with: "<a href=\"$2\">$1</a>")
        value = replace(#"`([^`\n]+)`"#, in: value, with: "<code>$1</code>")
        value = replace(#"\*\*([^*\n]+)\*\*|__([^_\n]+)__"#, in: value, with: "<strong>$1$2</strong>")
        value = replace(#"~~([^~\n]+)~~"#, in: value, with: "<del>$1</del>")
        value = replace(#"(?<!\*)\*([^*\n]+)\*(?!\*)|(?<!_)_([^_\n]+)_(?!_)"#, in: value, with: "<em>$1$2</em>")
        return value
    }

    private func imageSource(_ source: String, baseURL: URL?) -> String {
        guard let baseURL,
              !source.hasPrefix("http://"),
              !source.hasPrefix("https://"),
              !source.hasPrefix("file://") else {
            return source
        }
        let path = (source as NSString).expandingTildeInPath
        let url = path.hasPrefix("/")
            ? URL(fileURLWithPath: path)
            : baseURL.appendingPathComponent(path)
        return url.standardizedFileURL.absoluteString
    }

    private func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func replace(_ pattern: String, in value: String, with template: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return value }
        return expression.stringByReplacingMatches(
            in: value,
            range: NSRange(location: 0, length: (value as NSString).length),
            withTemplate: template
        )
    }
}

enum MarkdownExportError: LocalizedError, Equatable {
    case writeFailed(URL)

    var errorDescription: String? {
        switch self {
        case let .writeFailed(url):
            return "无法导出“\(url.lastPathComponent)”，请确认目标位置可写。"
        }
    }
}

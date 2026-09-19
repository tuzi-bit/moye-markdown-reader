import Foundation

struct MarkdownTaskItem: Identifiable, Equatable {
    let id: Int
    let text: String
    let isChecked: Bool
    let sourceLine: Int
}

struct MarkdownImage: Equatable {
    let source: String
    let altText: String
}

struct MarkdownOutlineItem: Identifiable, Equatable {
    let id: Int
    let blockID: Int
    let level: Int
    let title: String
}

struct MarkdownBlock: Identifiable {
    enum Kind {
        case heading(level: Int, text: String)
        case paragraph(String)
        case unorderedList([String])
        case orderedList([String])
        case taskList([MarkdownTaskItem])
        case quote(String)
        case code(language: String?, text: String)
        case math(String)
        case mermaid(String)
        case table(headers: [String], rows: [[String]])
        case image(MarkdownImage)
        case divider
    }

    let id: Int
    let kind: Kind
}

struct MarkdownRenderer {
    func render(_ source: String) -> AttributedString {
        renderInline(source)
    }

    func renderInline(_ source: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: source, options: options)) ?? AttributedString(source)
    }

    func outline(from source: String) -> [MarkdownOutlineItem] {
        blocks(from: source).compactMap { block in
            guard case let .heading(level, text) = block.kind else { return nil }
            return MarkdownOutlineItem(
                id: block.id,
                blockID: block.id,
                level: level,
                title: text
            )
        }
    }

    func blocks(from source: String) -> [MarkdownBlock] {
        let lines = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                index += 1
                continue
            }

            if let heading = heading(from: line) {
                blocks.append(MarkdownBlock(id: blocks.count, kind: .heading(
                    level: heading.level,
                    text: heading.text
                )))
                index += 1
                continue
            }

            if let inlineMath = singleLineMath(from: line) {
                blocks.append(MarkdownBlock(id: blocks.count, kind: .math(inlineMath)))
                index += 1
                continue
            }

            if isMathDelimiter(line) {

                index += 1
                var mathLines: [String] = []
                while index < lines.count {
                    if isMathDelimiter(lines[index]) {
                        index += 1
                        break
                    }
                    mathLines.append(lines[index])
                    index += 1
                }
                blocks.append(MarkdownBlock(id: blocks.count, kind: .math(
                    mathLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                )))
                continue
            }

            if let fenceLanguage = codeFenceLanguage(from: line) {
                let marker = String(UnicodeScalar(96)!)
                index += 1
                var codeLines: [String] = []
                while index < lines.count {
                    if lines[index].trimmingCharacters(in: .whitespaces).hasPrefix(marker) {
                        index += 1
                        break
                    }
                    codeLines.append(lines[index])
                    index += 1
                }
                let codeText = codeLines.joined(separator: "\n")
                if fenceLanguage.lowercased() == "mermaid" {
                    blocks.append(MarkdownBlock(id: blocks.count, kind: .mermaid(codeText)))
                } else {
                    blocks.append(MarkdownBlock(id: blocks.count, kind: .code(
                        language: fenceLanguage.isEmpty ? nil : fenceLanguage,
                        text: codeText
                    )))
                }
                continue
            }

            if isDivider(line) {
                blocks.append(MarkdownBlock(id: blocks.count, kind: .divider))
                index += 1
                continue
            }

            if let image = image(from: line) {
                blocks.append(MarkdownBlock(id: blocks.count, kind: .image(image)))
                index += 1
                continue
            }

            if let headers = tableRow(from: line),
               index + 1 < lines.count,
               isTableSeparator(lines[index + 1]) {
                index += 2
                var rows: [[String]] = []
                while index < lines.count, let row = tableRow(from: lines[index]) {
                    rows.append(row)
                    index += 1
                }
                blocks.append(MarkdownBlock(id: blocks.count, kind: .table(
                    headers: headers,
                    rows: rows
                )))
                continue
            }

            if let firstItem = listItem(from: line, lineIndex: index) {
                var listItems = [firstItem]
                index += 1
                while index < lines.count, let nextItem = listItem(from: lines[index], lineIndex: index),
                      nextItem.isOrdered == firstItem.isOrdered {
                    listItems.append(nextItem)
                    index += 1
                }
                let kind: MarkdownBlock.Kind
                if listItems.allSatisfy({ $0.task != nil }) {
                    let tasks: [MarkdownTaskItem] = listItems.enumerated().compactMap { index, item in
                        guard let task = item.task else { return nil }
                        return MarkdownTaskItem(
                            id: index,
                            text: task.text,
                            isChecked: task.isChecked,
                            sourceLine: item.sourceLine
                        )
                    }
                    kind = .taskList(tasks)
                } else if firstItem.isOrdered {
                    kind = .orderedList(listItems.map(\.text))
                } else {
                    kind = .unorderedList(listItems.map(\.text))
                }
                blocks.append(MarkdownBlock(id: blocks.count, kind: kind))
                continue
            }

            if line.trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                var quoteLines: [String] = []
                while index < lines.count {
                    let quoteLine = lines[index].trimmingCharacters(in: .whitespaces)
                    guard quoteLine.hasPrefix(">") else { break }
                    quoteLines.append(String(quoteLine.dropFirst()).trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                blocks.append(MarkdownBlock(id: blocks.count, kind: .quote(
                    quoteLines.joined(separator: "\n")
                )))
                continue
            }

            var paragraphLines = [line]
            index += 1
            while index < lines.count,
                  !lines[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !startsBlock(lines[index]) {
                paragraphLines.append(lines[index])
                index += 1
            }
            blocks.append(MarkdownBlock(id: blocks.count, kind: .paragraph(
                paragraphLines.joined(separator: "\n")
            )))
        }

        return blocks
    }

    private func heading(from line: String) -> (level: Int, text: String)? {
        let prefix = line.prefix { $0 == "#" }
        let level = prefix.count
        guard (1...6).contains(level),
              line.dropFirst(level).first == " " else {
            return nil
        }
        let text = line.dropFirst(level).trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return (level, text)
    }

    private func codeFenceLanguage(from line: String) -> String? {
        let marker = String(UnicodeScalar(96)!)
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(marker) else { return nil }
        let language = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
        return String(language)
    }

    private func isDivider(_ line: String) -> Bool {
        let compact = line.filter { !$0.isWhitespace }
        return compact == "---" || compact == "***" || compact == "___"
    }

    private func tableRow(from line: String) -> [String]? {
        guard line.contains("|") else { return nil }
        var value = line.trimmingCharacters(in: .whitespaces)
        if value.first == "|" {
            value.removeFirst()
        }
        if value.last == "|" {
            value.removeLast()
        }
        let cells = value.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        return cells.isEmpty ? nil : cells
    }

    private func isTableSeparator(_ line: String) -> Bool {
        guard let cells = tableRow(from: line), !cells.isEmpty else { return false }
        return cells.allSatisfy {
            let value = $0.trimmingCharacters(in: .whitespaces)
            return value.count >= 3
                && value.allSatisfy { $0 == "-" || $0 == ":" }
                && value.contains("-")
        }
    }

    private struct ParsedTask {
        let text: String
        let isChecked: Bool
    }

    private struct ParsedListItem {
        let isOrdered: Bool
        let text: String
        let task: ParsedTask?
        let sourceLine: Int
    }

    private func isMathDelimiter(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "$$"
    }

    private func singleLineMath(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 5,
              trimmed.hasPrefix("$$"),
              trimmed.hasSuffix("$$") else {
            return nil
        }
        let start = trimmed.index(trimmed.startIndex, offsetBy: 2)
        let end = trimmed.index(trimmed.endIndex, offsetBy: -2)
        let content = String(trimmed[start..<end]).trimmingCharacters(in: .whitespaces)
        return content.isEmpty ? nil : content
    }

    private func image(from line: String) -> MarkdownImage? {
        let pattern = #"^\s*!\[([^\]]*)\]\(([^)]+)\)\s*$"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: line,
                range: NSRange(location: 0, length: (line as NSString).length)
              ),
              let altRange = Range(match.range(at: 1), in: line),
              let sourceRange = Range(match.range(at: 2), in: line) else {
            return nil
        }
        return MarkdownImage(
            source: String(line[sourceRange]).trimmingCharacters(in: .whitespaces),
            altText: String(line[altRange])
        )
    }

    private func listItem(from line: String, lineIndex: Int) -> ParsedListItem? {
        let pattern = #"^\s*(?:(\d+)[.)]|[-*+])\s+(.+)$"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: line,
                range: NSRange(location: 0, length: (line as NSString).length)
              ),
              let textRange = Range(match.range(at: 2), in: line) else {
            return nil
        }
        let rawText = String(line[textRange])
        let task = parsedTask(from: rawText)
        return ParsedListItem(
            isOrdered: match.range(at: 1).location != NSNotFound,
            text: task?.text ?? rawText,
            task: task,
            sourceLine: lineIndex
        )
    }

    private func parsedTask(from text: String) -> ParsedTask? {
        let pattern = #"^\[([ xX])\]\s+(.+)$"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: text,
                range: NSRange(location: 0, length: (text as NSString).length)
              ),
              let markerRange = Range(match.range(at: 1), in: text),
              let textRange = Range(match.range(at: 2), in: text) else {
            return nil
        }
        return ParsedTask(
            text: String(text[textRange]),
            isChecked: text[markerRange].lowercased() == "x"
        )
    }

    private func startsBlock(_ line: String) -> Bool {
        heading(from: line) != nil
            || codeFenceLanguage(from: line) != nil
            || isMathDelimiter(line)
            || isDivider(line)
            || image(from: line) != nil
            || listItem(from: line, lineIndex: 0) != nil
            || line.trimmingCharacters(in: .whitespaces).hasPrefix(">")
    }
}

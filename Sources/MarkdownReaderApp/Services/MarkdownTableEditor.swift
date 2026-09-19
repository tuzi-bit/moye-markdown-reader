import Foundation

struct MarkdownTableEditorSession: Equatable {
    let startLine: Int
    let endLine: Int
    var headers: [String]
    var rows: [[String]]

    var columnCount: Int {
        max(headers.count, rows.map(\.count).max() ?? 0)
    }

    var normalizedHeaders: [String] {
        normalized(headers)
    }

    var normalizedRows: [[String]] {
        rows.map(normalized)
    }

    private func normalized(_ cells: [String]) -> [String] {
        Array(cells + Array(repeating: "", count: max(0, columnCount - cells.count)))
            .prefix(columnCount)
            .map { $0 }
    }
}

struct MarkdownTableEditor {
    func firstTable(in source: String) -> MarkdownTableEditorSession? {
        let lines = normalizedLines(source)
        var index = 0
        while index + 1 < lines.count {
            guard let headers = cells(from: lines[index]),
                  isSeparator(lines[index + 1]) else {
                index += 1
                continue
            }

            var endLine = index + 1
            var rows: [[String]] = []
            while endLine + 1 < lines.count,
                  let row = cells(from: lines[endLine + 1]) {
                rows.append(row)
                endLine += 1
            }
            return MarkdownTableEditorSession(
                startLine: index,
                endLine: endLine,
                headers: headers,
                rows: rows
            )
        }
        return nil
    }

    func replacingFirstTable(
        in source: String,
        with session: MarkdownTableEditorSession
    ) -> String {
        let lines = normalizedLines(source)
        guard lines.indices.contains(session.startLine),
              lines.indices.contains(session.endLine) else {
            return source
        }

        let columns = max(1, session.columnCount)
        let headers = Array(session.normalizedHeaders.prefix(columns))
        let separator = Array(repeating: "---", count: columns)
        var replacement = [formatRow(headers), formatRow(separator)]
        replacement.append(contentsOf: session.normalizedRows.map(formatRow))

        var updatedLines = lines
        updatedLines.replaceSubrange(session.startLine...session.endLine, with: replacement)
        return updatedLines.joined(separator: "\n")
    }

    private func normalizedLines(_ source: String) -> [String] {
        source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
    }

    private func cells(from line: String) -> [String]? {
        guard line.contains("|") else { return nil }
        var value = line.trimmingCharacters(in: .whitespaces)
        if value.first == "|" { value.removeFirst() }
        if value.last == "|" { value.removeLast() }
        let result = value.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        return result.isEmpty ? nil : result
    }

    private func isSeparator(_ line: String) -> Bool {
        guard let cells = cells(from: line), !cells.isEmpty else { return false }
        return cells.allSatisfy { value in
            value.count >= 3
                && value.contains("-")
                && value.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    private func formatRow(_ cells: [String]) -> String {
        "| " + cells.map { $0.replacingOccurrences(of: "|", with: "\\|") }
            .joined(separator: " | ") + " |"
    }
}

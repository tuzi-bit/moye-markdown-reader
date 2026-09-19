import SwiftUI

struct TableEditorView: View {
    let session: MarkdownTableEditorSession
    let onSave: (MarkdownTableEditorSession) -> Void
    let onCancel: () -> Void

    @State private var headers: [String]
    @State private var rows: [[String]]

    init(
        session: MarkdownTableEditorSession,
        onSave: @escaping (MarkdownTableEditorSession) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.session = session
        self.onSave = onSave
        self.onCancel = onCancel
        let columnCount = max(1, session.columnCount)
        _headers = State(initialValue: Self.normalized(session.headers, count: columnCount))
        _rows = State(initialValue: session.rows.map {
            Self.normalized($0, count: columnCount)
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("编辑表格")
                .font(.title2.weight(.semibold))

            Text("修改表头和单元格，保存后会写回 Markdown 表格。")
                .foregroundStyle(.secondary)

            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 8) {
                    tableRow(indices: headers.indices, header: true)
                    Divider()
                    ForEach(rows.indices, id: \.self) { rowIndex in
                        tableRow(indices: rows[rowIndex].indices, rowIndex: rowIndex, header: false)
                    }
                }
                .padding(4)
            }
            .frame(minHeight: 180)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.45), in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 8) {
                Button("添加行") {
                    rows.append(Array(repeating: "", count: max(1, headers.count)))
                }
                Button("添加列") {
                    headers.append("")
                    for index in rows.indices {
                        rows[index].append("")
                    }
                }
                Button("删除最后一行") {
                    guard !rows.isEmpty else { return }
                    rows.removeLast()
                }
                .disabled(rows.isEmpty)
                Button("删除最后一列") {
                    guard headers.count > 1 else { return }
                    headers.removeLast()
                    for index in rows.indices where !rows[index].isEmpty {
                        rows[index].removeLast()
                    }
                }
                .disabled(headers.count <= 1)
                Spacer()
                Button("取消", role: .cancel, action: onCancel)
                Button("保存") {
                    onSave(MarkdownTableEditorSession(
                        startLine: session.startLine,
                        endLine: session.endLine,
                        headers: headers,
                        rows: rows
                    ))
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 680, minHeight: 360)
    }

    @ViewBuilder
    private func tableRow(
        indices: Range<Int>,
        rowIndex: Int? = nil,
        header: Bool
    ) -> some View {
        HStack(spacing: 8) {
            ForEach(indices, id: \.self) { columnIndex in
                TextField(
                    header ? "表头" : "内容",
                    text: cellBinding(rowIndex: rowIndex, columnIndex: columnIndex)
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
            }
        }
        .font(header ? .headline : .body)
    }

    private func cellBinding(rowIndex: Int?, columnIndex: Int) -> Binding<String> {
        Binding(
            get: {
                if let rowIndex {
                    guard rows.indices.contains(rowIndex), rows[rowIndex].indices.contains(columnIndex) else {
                        return ""
                    }
                    return rows[rowIndex][columnIndex]
                }
                return headers.indices.contains(columnIndex) ? headers[columnIndex] : ""
            },
            set: { value in
                if let rowIndex {
                    guard rows.indices.contains(rowIndex), rows[rowIndex].indices.contains(columnIndex) else { return }
                    rows[rowIndex][columnIndex] = value
                } else if headers.indices.contains(columnIndex) {
                    headers[columnIndex] = value
                }
            }
        )
    }

    private static func normalized(_ cells: [String], count: Int) -> [String] {
        Array((cells + Array(repeating: "", count: max(0, count - cells.count))).prefix(count))
    }
}

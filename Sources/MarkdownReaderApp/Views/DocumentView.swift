import SwiftUI

struct DocumentView: View {
    let document: MarkdownDocument
    @EnvironmentObject private var store: AppStore
    private let renderer = MarkdownRenderer()

    var body: some View {
        VStack(spacing: 0) {
            if !store.openDocumentTabs.isEmpty {
                DocumentTabBar()
            }
            documentHeader
            if store.showsFindReplace {
                FindReplaceBar()
            }
            Divider()
            if store.isEditing {
                editingWorkspace
            } else {
                previewWorkspace
            }
            documentStatusBar
        }
        .background(Color(nsColor: .textBackgroundColor))
        .sheet(isPresented: $store.showsTableEditor) {
            if let table = store.editableTable {
                TableEditorView(
                    session: table,
                    onSave: { store.applyTableEditor($0) },
                    onCancel: { store.closeTableEditor() }
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if store.isEditing {
                    Picker("编辑模式", selection: $store.showsSourceEditor) {
                        Text("所见即所得").tag(false)
                        Text("源码").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 142)

                    Button {
                        store.saveDocument()
                    } label: {
                        Label("保存", systemImage: "square.and.arrow.down")
                    }
                    .keyboardShortcut("s", modifiers: [.command])
                    .disabled(!store.isDirty)

                    Button {
                        store.saveAsDocument()
                    } label: {
                        Label("另存为…", systemImage: "square.and.arrow.down.on.square")
                    }

                    Menu {
                        Button("插入表格模板", systemImage: "tablecells") {
                            store.insertTableTemplate()
                        }
                        Button("编辑当前表格", systemImage: "pencil.and.outline") {
                            store.openTableEditor()
                        }
                    } label: {
                        Label("插入", systemImage: "plus")
                    }

                    Button("完成") {
                        store.finishEditing()
                    }
                } else {
                    Button {
                        store.beginEditing()
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }

                    Button {
                        store.saveDocument()
                    } label: {
                        Label("保存", systemImage: "square.and.arrow.down")
                    }
                    .keyboardShortcut("s", modifiers: [.command])
                    .disabled(!store.isDirty)

                    Button {
                        store.saveAsDocument()
                    } label: {
                        Label("另存为…", systemImage: "square.and.arrow.down.on.square")
                    }
                }

                Menu {
                    Button("导出 HTML…", systemImage: "doc.richtext") {
                        store.exportHTMLDocument()
                    }
                    Button("打印或导出 PDF…", systemImage: "printer") {
                        store.printDocument()
                    }
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }

                Button {
                    store.toggleFindReplace()
                } label: {
                    Label("查找", systemImage: "magnifyingglass")
                }
            }
        }
    }

    private var documentHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(document.title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    if store.isDirty {
                        Circle()
                            .fill(.orange)
                            .frame(width: 8, height: 8)
                            .help("有未保存修改")
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                    Text(document.url.path)
                        .lineLimit(1)
                    if let modifiedAt = document.modifiedAt {
                        Text("·")
                        Text(modifiedAt, style: .date)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if store.isEditing {
                Text("编辑中")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.tint.opacity(0.12), in: Capsule())
            }
        }
        .frame(maxWidth: 980, alignment: .leading)
        .padding(.horizontal, 40)
        .padding(.vertical, 24)
    }

    private var previewWorkspace: some View {
        MarkdownPreviewView(
            source: $store.draftText,
            baseURL: document.url.deletingLastPathComponent(),
            scrollRequest: store.headingNavigationRequest,
            onToggleTask: { store.toggleTask($0) }
        )
    }

    private var editingWorkspace: some View {
        Group {
            if store.showsSourceEditor {
                TextEditor(text: Binding(
                    get: { store.draftText },
                    set: { store.updateDraft($0) }
                ))
                .font(.system(size: 16, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))
                .padding(.horizontal, 36)
                .padding(.vertical, 28)
            } else {
                WYSIWYGMarkdownEditor(text: Binding(
                    get: { store.draftText },
                    set: { store.updateDraft($0) }
                ))
                .background(Color(nsColor: .textBackgroundColor))
                .padding(.horizontal, 36)
                .padding(.vertical, 20)
            }
        }
        .frame(maxWidth: 900, maxHeight: .infinity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var documentStatusBar: some View {
        HStack(spacing: 12) {
            Text("行数 \(lineCount)")
            Text("字符 \(characterCount)")
            if store.isDirty {
                Text("有未保存修改")
                    .foregroundStyle(.orange)
            } else {
                Text("已保存")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 40)
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private var lineCount: Int {
        max(1, store.draftText.components(separatedBy: .newlines).count)
    }

    private var characterCount: Int {
        store.draftText.filter { !$0.isWhitespace }.count
    }
}

private struct DocumentTabBar: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(store.openDocumentTabs) { tab in
                    HStack(spacing: 6) {
                        Button {
                            store.selectOpenDocument(tab.url)
                        } label: {
                            Label(tab.title, systemImage: "doc.text")
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)

                        Button {
                            store.closeDocumentTab(tab)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2.weight(.bold))
                        }
                        .buttonStyle(.plain)
                        .help("关闭标签页")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        store.selectedURL?.standardizedFileURL == tab.url.standardizedFileURL
                            ? Color.accentColor.opacity(0.14)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}

private struct FindReplaceBar: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("查找", text: $store.findText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
            TextField("替换为", text: $store.replacementText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
            Text("\(store.findMatchCount) 个匹配")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("替换") {
                store.replaceNextMatch()
            }
            .disabled(store.findText.isEmpty || store.findMatchCount == 0)

            Button("全部替换") {
                store.replaceAllMatches()
            }
            .disabled(store.findText.isEmpty || store.findMatchCount == 0)

            Button {
                store.closeFindReplace()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .help("关闭查找")
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }
}

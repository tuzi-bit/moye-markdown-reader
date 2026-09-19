import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchField
            tree
                .frame(maxHeight: .infinity)
            if !store.isEditing, !store.documentOutline.isEmpty {
                Divider()
                DocumentOutlineView(items: store.documentOutline)
                    .frame(maxHeight: 220)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("墨页")
                    .font(.headline)
                Text(store.workspaceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Menu {
                Button("打开文件夹…", systemImage: "folder") { store.chooseFolder() }
                Button("打开 Markdown 文件…", systemImage: "doc") { store.chooseMarkdownFile() }
                if !store.recentDocumentURLs.isEmpty {
                    Divider()
                    Menu("最近打开", systemImage: "clock") {
                        ForEach(store.recentDocumentURLs, id: \.self) { url in
                            Button(url.lastPathComponent) {
                                store.openRecentDocument(url)
                            }
                        }
                    }
                }
                Divider()
                Button("新建 Markdown 文件", systemImage: "doc.badge.plus") { store.createNewFile() }
                Button("新建文件夹", systemImage: "folder.badge.plus") { store.createNewFolder() }
                Divider()
                Picker("主题", selection: $store.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Label(appearance.title, systemImage: appearance.systemImage)
                            .tag(appearance)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 17, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("新建、打开和外观")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索文档", text: $store.searchText)
                .textFieldStyle(.plain)
            if !store.searchText.isEmpty {
                Button {
                    store.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(7)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var tree: some View {
        Group {
            if store.visibleTree.isEmpty {
                EmptySidebarView(hasWorkspace: store.rootURL != nil)
            } else {
                List(store.visibleTree, children: \.optionalChildren, selection: $store.selectedURL) { node in
                    WorkspaceNodeRow(node: node)
                        .tag(node.url)
                        .contextMenu {
                            if !node.isFolder {
                                Button("打开") { store.select(node) }
                                Button("重命名…") {
                                    store.requestRename(node)
                                }
                                Button("从工作区移除") {
                                    store.requestRemoveFromWorkspace(node)
                                }
                            }
                        }
                }
                .listStyle(.sidebar)
                .onChange(of: store.selectedURL) { url in
                    guard let url else { return }
                    if let node = findNode(url, in: store.tree) {
                        store.select(node)
                    }
                }
            }
        }
    }

    private func findNode(_ url: URL, in nodes: [WorkspaceNode]) -> WorkspaceNode? {
        for node in nodes {
            if node.url == url { return node }
            if let match = findNode(url, in: node.children) { return match }
        }
        return nil
    }
}

private struct DocumentOutlineView: View {
    @EnvironmentObject private var store: AppStore
    let items: [MarkdownOutlineItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("文档大纲", systemImage: "list.bullet.indent")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 4)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(items) { item in
                        Button {
                            store.navigateToHeading(item)
                        } label: {
                            Text(item.title)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                                .padding(.leading, CGFloat(max(0, item.level - 1) * 12))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(item.level == 1 ? .primary : .secondary)
                        .padding(.horizontal, 10)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.bottom, 6)
    }
}

struct WorkspaceNodeRow: View {
    let node: WorkspaceNode

    var body: some View {
        Label {
            Text(node.name)
                .lineLimit(1)
        } icon: {
            Image(systemName: node.isFolder ? "folder" : "doc.text")
                .foregroundStyle(node.isFolder ? .yellow : .secondary)
        }
        .padding(.vertical, 2)
    }
}

struct EmptySidebarView: View {
    let hasWorkspace: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: hasWorkspace ? "doc.text.magnifyingglass" : "folder.badge.questionmark")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(hasWorkspace ? "没有匹配的文档" : "打开一个 Markdown 工作区")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

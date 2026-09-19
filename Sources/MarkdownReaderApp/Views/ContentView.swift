import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .frame(minWidth: 250, idealWidth: 290)
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    DropURLReader.read(from: providers) { urls in
                        store.handleExternalOpen(urls: urls)
                    }
                    return true
                }
        } detail: {
            DetailView(router: store.router)
        }
        .navigationSplitViewStyle(.balanced)
        .alert("无法打开", isPresented: errorBinding) {
            Button("好") { store.clearError() }
        } message: {
            Text(store.errorMessage ?? "未知错误")
        }
        .alert("从工作区移除？", isPresented: removalBinding) {
            Button("取消", role: .cancel) {
                store.cancelRemoveFromWorkspace()
            }
            Button("移除") {
                store.confirmRemoveFromWorkspace()
            }
        } message: {
            Text("只会从当前工作区的左侧目录中移除，不会删除磁盘上的文件。之后重新打开或导入该文件即可再次加入。")
        }
        .alert("文件已在其他程序中修改", isPresented: externalChangeBinding) {
            Button("保留当前编辑", role: .cancel) {
                store.keepCurrentDocumentAfterExternalChange()
            }
            Button("重新加载文件") {
                store.reloadAfterExternalChange()
            }
        } message: {
            Text("当前文档在墨页之外发生了变化。重新加载会放弃当前未保存内容；保留当前编辑则继续使用窗口中的版本。")
        }
        .alert(
            store.fileNamePrompt?.title ?? "文件名",
            isPresented: fileNamePromptBinding
        ) {
            TextField("文件名", text: $store.fileNameInput)
            Button("取消", role: .cancel) {
                store.cancelFileNamePrompt()
            }
            Button(store.fileNamePrompt?.confirmTitle ?? "确定") {
                store.confirmFileNamePrompt()
            }
        } message: {
            Text([
                store.fileNamePromptError ?? "扩展名会自动使用 .md。文件名不能包含路径分隔符。",
                "保存位置：\(store.fileNamePrompt?.directory.path ?? "未指定")"
            ].joined(separator: "\n"))
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { isPresented in
                if !isPresented { store.clearError() }
            }
        )
    }

    private var removalBinding: Binding<Bool> {
        Binding(
            get: { store.removalCandidate != nil },
            set: { isPresented in
                if !isPresented { store.cancelRemoveFromWorkspace() }
            }
        )
    }

    private var fileNamePromptBinding: Binding<Bool> {
        Binding(
            get: { store.fileNamePrompt != nil },
            set: { isPresented in
                if !isPresented {
                    store.cancelFileNamePrompt()
                }
            }
        )
    }

    private var externalChangeBinding: Binding<Bool> {
        Binding(
            get: { store.externalChangeCandidate != nil },
            set: { isPresented in
                if !isPresented {
                    store.keepCurrentDocumentAfterExternalChange()
                }
            }
        )
    }
}

struct DetailView: View {
    @ObservedObject var router: AppRouter
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Group {
            if case .document = router.route, let document = store.selectedDocument {
                DocumentView(document: document)
            } else {
                WelcomeView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.showDefaultAppInstructions()
                } label: {
                    Label("默认打开方式", systemImage: "arrow.down.doc")
                }
                .help("设置 Markdown 文件的默认打开方式")
            }
        }
    }

}

enum DropURLReader {
    static func read(from providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
        let group = DispatchGroup()
        var urls: [URL] = []
        let lock = NSLock()

        for provider in providers where provider.hasItemConformingToTypeIdentifier("public.file-url") {
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                defer { group.leave() }
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = item as? URL
                }
                guard let url else { return }
                lock.lock()
                urls.append(url)
                lock.unlock()
            }
        }

        group.notify(queue: .main) {
            completion(urls)
        }
    }
}

import SwiftUI

@main
struct MarkdownReaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AppStore()

    var body: some Scene {
        Window("墨页", id: "main") {
            ContentView()
                .environmentObject(store)
                .onAppear {
                    store.handleExternalOpen(urls: appDelegate.takePendingURLs())
                }
            .onReceive(NotificationCenter.default.publisher(for: .markdownReaderDidReceiveURLs)) { notification in
                guard let urls = notification.object as? [URL] else { return }
                store.handleExternalOpen(urls: urls)
            }
            .preferredColorScheme(store.appearance.colorScheme)
        }
        .commands {
            AppCommands(store: store)
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}

struct AppCommands: Commands {
    @ObservedObject var store: AppStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("打开文件夹…") {
                store.chooseFolder()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Button("打开 Markdown 文件…") {
                store.chooseMarkdownFile()
            }
            .keyboardShortcut("o", modifiers: [.command])

            Divider()

            Button("新建 Markdown 文件") {
                store.createNewFile()
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button("新建文件夹") {
                store.createNewFolder()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            Button("保存文档") {
                store.saveDocument()
            }
            .keyboardShortcut("s", modifiers: [.command])
            .disabled(!store.isDirty)

            Button("另存为…") {
                store.saveAsDocument()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Button("导出 HTML…") {
                store.exportHTMLDocument()
            }

            Button("打印或导出 PDF…") {
                store.printDocument()
            }
            .keyboardShortcut("p", modifiers: [.command])

            Button("查找或替换…") {
                store.toggleFindReplace()
            }
            .keyboardShortcut("f", modifiers: [.command])
        }

        CommandGroup(after: .appInfo) {
            Button("设置 Markdown 默认打开方式…") {
                store.showDefaultAppInstructions()
            }
        }
    }
}

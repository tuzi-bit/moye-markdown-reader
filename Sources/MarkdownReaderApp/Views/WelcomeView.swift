import AppKit
import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 76, height: 76)
                .accessibilityLabel("墨页应用图标")
            Text("墨页")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
            Text("打开一个文件夹开始阅读\n也可以把文件或文件夹拖到 App 图标上")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .lineSpacing(4)

            HStack(spacing: 12) {
                Button("打开文件夹…") { store.chooseFolder() }
                    .buttonStyle(.borderedProminent)
                Button("打开文件…") { store.chooseMarkdownFile() }
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Form {
            Section("文件关联") {
                Text("将墨页设置为 .md 文件的默认打开方式后，双击 Markdown 文件即可直接阅读。")
                    .fixedSize(horizontal: false, vertical: true)
                Button("查看设置说明") {
                    store.showDefaultAppInstructions()
                }
            }

            Section("外观") {
                Picker("主题", selection: $store.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Label(appearance.title, systemImage: appearance.systemImage)
                            .tag(appearance)
                    }
                }
                Text("深色主题会同时应用到阅读区、编辑区和侧边栏。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 420)
        .preferredColorScheme(store.appearance.colorScheme)
    }
}

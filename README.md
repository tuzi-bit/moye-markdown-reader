# 墨页 for macOS

墨页是一款以可读性、可维护性和可测试性为优先的原生 SwiftUI Markdown 阅读器。界面采用左侧文件树、右侧阅读区的布局，支持导入/打开 Markdown 文件夹或文件、新建 Markdown 文件和文件夹，以及从 Finder 将文件或文件夹拖到 App 图标打开。

## 功能

- 左侧展示当前工作区中的 Markdown 文件夹树，文件夹优先排序。
- 支持通过文件右键菜单“从工作区移除”；只会隐藏并持久化工作区排除状态，不会删除磁盘文件。
- 右侧使用系统 `AttributedString` Markdown 解析器渲染标题、列表、链接、代码和强调文本。
- 预览支持文档大纲：左侧显示当前文档的标题层级，点击标题可跳转到对应内容。
- 预览支持任务列表、独立图片（相对路径、本地绝对路径和 HTTP(S) 地址）以及删除线；编辑器中回车会自动延续无序列表、有序列表和任务列表。
- 支持导出 HTML；支持通过系统打印面板打印或导出 PDF。阅读区底部显示行数、字符数和当前保存状态。
- 编辑中的文档会在停止输入约 1.2 秒后自动保存；如果文件被其他程序修改，未保存时会提示选择重新加载或保留当前编辑，避免静默覆盖内容。
- 支持当前文档查找、替换和全部替换（`⌘F`）；编辑状态下可从“插入”菜单追加表格模板，减少重复输入。
- 支持表格可视化编辑、任务列表点击切换状态、`$$...$$` 数学块和基础 Mermaid 流程图预览。
- 支持浅色、深色和跟随系统主题，可从侧边栏顶部的“更多操作”菜单直接切换；已打开文档显示为标签页，并保留最近打开的 Markdown 文件。
- 从程序坞再次点击时会激活应用并恢复已隐藏或最小化的主窗口；自动保存任务和文件变化监听在切换文档、关闭窗口和应用退出时都会取消，避免后台任务和引用长期残留。
- 打开或新建文档后点击“编辑”，默认进入所见即所得编辑；标题、加粗、斜体、行内代码和链接会直接呈现样式，也可切换到“源码”模式；支持“保存”、“另存为…”、`⌘S` 保存和“完成”退出编辑。
- 保存行为接近 Typora：`⌘S` 保存当前文件，`⌘⇧S` 打开“另存为”面板；另存为成功后会切换到新文件继续编辑，原文件保留不变。保存面板会自动补全 `.md` 扩展名。
- `打开文件夹`、`打开文件`、`新建 Markdown 文件`、`新建文件夹`。新建文件时可先输入名称，创建确认框会显示实际保存目录；有工作区时保存到当前选中文件夹，选中文件时保存到该文件所在目录，没有打开工作区时自动创建到 `~/Documents/Markdown Reader`，并立即进入编辑状态。
- 左侧 Markdown 文件支持通过右键菜单重命名，扩展名统一保留为 `.md`，重命名会同步修改磁盘上的文件。
- App 内侧边栏支持拖放文件或文件夹；App 图标支持 Finder 外部拖入，入口由 `NSApplicationDelegate` 的 `application(_:open:)` 接收。
- `Info.plist` 声明 `.md`、`.markdown`、`.mdown`、`.mkdn` 文件类型，安装后可在 Finder 中将本 App 设为默认打开方式。
- 使用 `Resources/AppIcon.png` 生成多尺寸 `AppIcon.icns`，打包后的 App 使用墨页专属图标。
- 内置“设为默认打开方式”说明，避免未经用户同意修改系统文件关联。
- 文件系统、文件选择器、路由和状态管理均有明确边界，核心逻辑可注入测试。

## 运行

需要 macOS 13 或更高版本。

```bash
swift test
swift run MarkdownReader
```

如需打包成可双击打开的 `.app`：

```bash
./scripts/build-app.sh
open build/墨页.app
```

若使用 Xcode，可新建一个 macOS App target，将 `Sources/MarkdownReaderApp` 加入 target，并将 `Resources/Info.plist` 设置为 target 的 Info.plist。工程入口是 `MarkdownReaderApp.swift`。

## 设为 Markdown 默认打开方式

安装或运行打包后的 App 后，在 Finder 中选中任意 `.md` 文件：

1. 右键选择“显示简介”。
2. 在“打开方式”中选择 `墨页`。
3. 点击“全部更改…”，确认将所有同类 Markdown 文件交给本 App 打开。

这是 macOS 推荐的用户可见流程；应用只声明自己的文档类型，不会静默篡改用户的 Launch Services 设置。

## 目录结构

```text
Sources/MarkdownReaderApp/
├── AppDelegate.swift
├── MarkdownReaderApp.swift
├── Models/              # 文档、工作区节点和路由
├── Services/            # 文件系统、文件选择器、Markdown 渲染
├── Stores/              # AppStore，唯一的界面状态入口
└── Views/               # Sidebar、树、欢迎页和阅读区
Tests/MarkdownReaderAppTests/
scripts/build-app.sh
Resources/Info.plist
```

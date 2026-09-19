import AppKit
import Foundation
import SwiftUI

struct FileNamePrompt: Identifiable {
    enum Action {
        case create(directory: URL)
        case rename(document: URL)
    }

    let id = UUID()
    let action: Action

    var title: String {
        switch action {
        case .create:
            return "新建 Markdown 文件"
        case .rename:
            return "重命名 Markdown 文件"
        }
    }

    var confirmTitle: String {
        switch action {
        case .create:
            return "创建"
        case .rename:
            return "重命名"
        }
    }

    var directory: URL {
        switch action {
        case let .create(directory):
            return directory
        case let .rename(document):
            return document.deletingLastPathComponent()
        }
    }
}

struct HeadingNavigationRequest: Identifiable, Equatable {
    let id = UUID()
    let blockID: Int
}

@MainActor
final class AppStore: ObservableObject {
    let fileSystem: FileSystemService
    let filePicker: FilePickerService
    let router: AppRouter
    let defaultAppService: DefaultAppService
    let exclusionStore: WorkspaceExclusionStore
    let newDocumentLocationProvider: NewDocumentLocationProviding
    let exportService: MarkdownExportService
    let textSearch: MarkdownTextSearch

    @Published private(set) var tree: [WorkspaceNode] = []
    @Published private(set) var openDocumentTabs: [DocumentTab] = []
    @Published private(set) var recentDocumentURLs: [URL] = []
    @Published private(set) var selectedDocument: MarkdownDocument?
    @Published var selectedURL: URL?
    @Published var searchText = ""
    @Published var findText = ""
    @Published var replacementText = ""
    @Published var showsFindReplace = false
    @Published var showsTableEditor = false
    @Published var appearance: AppAppearance = .system {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceDefaultsKey)
        }
    }
    @Published var draftText = ""
    @Published var showsSourceEditor = false
    @Published private(set) var isEditing = false
    @Published private(set) var isDirty = false
    @Published private(set) var rootURL: URL?
    @Published private(set) var errorMessage: String?
    @Published private(set) var removalCandidate: URL?
    @Published private(set) var externalChangeCandidate: URL?
    @Published private(set) var fileNamePrompt: FileNamePrompt?
    @Published var fileNameInput = ""
    @Published private(set) var fileNamePromptError: String?
    @Published private(set) var headingNavigationRequest: HeadingNavigationRequest?
    private var excludedURLs = Set<URL>()
    private var autoSaveTask: Task<Void, Never>?
    private var fileWatchTimer: Timer?
    private var ignoredExternalChangeDate: Date?

    private static let recentDocumentsDefaultsKey = "MarkdownReader.recentDocuments"
    private static let appearanceDefaultsKey = "MarkdownReader.appearance"

    deinit {
        autoSaveTask?.cancel()
        fileWatchTimer?.invalidate()
        fileWatchTimer = nil
    }

    init(
        fileSystem: FileSystemService = LocalFileSystemService(),
        filePicker: FilePickerService = OpenPanelFilePicker(),
        router: AppRouter? = nil,
        defaultAppService: DefaultAppService = DefaultAppService(),
        exclusionStore: WorkspaceExclusionStore = UserDefaultsWorkspaceExclusionStore(),
        newDocumentLocationProvider: NewDocumentLocationProviding = DocumentsNewDocumentLocationProvider(),
        exportService: MarkdownExportService = MarkdownExportService(),
        textSearch: MarkdownTextSearch = MarkdownTextSearch()
    ) {
        self.fileSystem = fileSystem
        self.filePicker = filePicker
        self.router = router ?? AppRouter()
        self.defaultAppService = defaultAppService
        self.exclusionStore = exclusionStore
        self.newDocumentLocationProvider = newDocumentLocationProvider
        self.exportService = exportService
        self.textSearch = textSearch
        appearance = AppAppearance(
            rawValue: UserDefaults.standard.string(forKey: Self.appearanceDefaultsKey) ?? ""
        ) ?? .system
        recentDocumentURLs = Self.loadRecentDocumentURLs()
    }

    var visibleTree: [WorkspaceNode] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return tree
        }
        return tree.compactMap { $0.filtered(matching: searchText) }
    }

    var workspaceName: String {
        rootURL?.lastPathComponent ?? "未打开工作区"
    }

    var documentOutline: [MarkdownOutlineItem] {
        guard selectedDocument != nil else { return [] }
        return MarkdownRenderer().outline(from: draftText)
    }

    func chooseFolder() {
        guard let url = filePicker.chooseFolder() else { return }
        open(urls: [url])
    }

    func chooseMarkdownFile() {
        guard let url = filePicker.chooseMarkdownFile() else { return }
        open(urls: [url])
    }

    func handleExternalOpen(urls: [URL]) {
        guard !urls.isEmpty else { return }
        open(urls: urls)
    }

    func open(urls: [URL]) {
        guard let url = urls.first else { return }
        let resolvedURL = url.resolvingSymlinksInPath().standardizedFileURL
        let values = try? resolvedURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])

        if values?.isDirectory == true {
            openWorkspace(at: resolvedURL)
        } else if values?.isRegularFile == true {
            openDocument(at: resolvedURL)
        } else {
            showError("无法打开该项目，请选择一个文件夹或 Markdown 文件。")
        }
    }

    func select(_ node: WorkspaceNode) {
        guard !node.isFolder else {
            router.navigate(to: .folder(node.url))
            return
        }
        openDocument(at: node.url)
    }

    func selectOpenDocument(_ url: URL) {
        openDocument(at: url)
    }

    func closeDocumentTab(_ tab: DocumentTab) {
        guard canLeaveCurrentDocument else { return }
        guard let index = openDocumentTabs.firstIndex(of: tab) else { return }
        let wasSelected = selectedURL?.standardizedFileURL == tab.url.standardizedFileURL
        openDocumentTabs.remove(at: index)

        guard wasSelected else { return }
        if !openDocumentTabs.isEmpty {
            let nextIndex = min(index, openDocumentTabs.count - 1)
            openDocument(at: openDocumentTabs[nextIndex].url)
            return
        }

        stopFileWatch()
        selectedURL = nil
        selectedDocument = nil
        draftText = ""
        isEditing = false
        isDirty = false
        router.navigate(to: rootURL.map(AppRoute.folder) ?? .welcome)
    }

    func openRecentDocument(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            recentDocumentURLs.removeAll { $0.standardizedFileURL == url.standardizedFileURL }
            persistRecentDocumentURLs()
            return
        }
        open(urls: [url])
    }

    func requestRemoveFromWorkspace(_ node: WorkspaceNode) {
        guard !node.isFolder else { return }
        guard canLeaveCurrentDocument else { return }
        removalCandidate = node.url
    }

    func requestRename(_ node: WorkspaceNode) {
        guard !node.isFolder else { return }
        guard canLeaveCurrentDocument else { return }
        fileNamePromptError = nil
        fileNameInput = node.url.deletingPathExtension().lastPathComponent
        fileNamePrompt = FileNamePrompt(action: .rename(document: node.url))
    }

    func cancelFileNamePrompt() {
        fileNamePrompt = nil
        fileNamePromptError = nil
    }

    func confirmFileNamePrompt() {
        guard let prompt = fileNamePrompt else { return }
        guard let destinationURL = markdownURL(for: fileNameInput, in: prompt.directory) else {
            fileNamePromptError = "请输入有效的文件名，扩展名会自动使用 .md。"
            return
        }

        do {
            switch prompt.action {
            case let .create(directory):
                let directory = try ensureWorkspaceDirectory(at: directory)
                let destinationURL = markdownURL(for: fileNameInput, in: directory)!
                try fileSystem.createFile(at: destinationURL, contents: "# 未命名文档\n\n")
                fileNamePrompt = nil
                fileNamePromptError = nil
                if rootURL == nil {
                    try openImplicitWorkspace(at: directory, showing: destinationURL)
                } else {
                    reloadTree(selecting: destinationURL)
                }
                openDocument(at: destinationURL)
                beginEditing()

            case let .rename(document):
                if document.standardizedFileURL == destinationURL.standardizedFileURL {
                    cancelFileNamePrompt()
                    return
                }
                try fileSystem.renameMarkdown(at: document, to: destinationURL)
                if let tabIndex = openDocumentTabs.firstIndex(where: {
                    $0.url.standardizedFileURL == document.standardizedFileURL
                }), let renamedDocument = try? fileSystem.readMarkdown(at: destinationURL) {
                    openDocumentTabs[tabIndex] = DocumentTab(document: renamedDocument)
                }
                let wasEditing = isEditing
                fileNamePrompt = nil
                fileNamePromptError = nil
                openDocument(at: destinationURL)
                if wasEditing {
                    beginEditing()
                }
            }
        } catch {
            fileNamePromptError = error.localizedDescription
        }
    }

    func cancelRemoveFromWorkspace() {
        removalCandidate = nil
    }

    func confirmRemoveFromWorkspace() {
        guard let removalCandidate, let rootURL else { return }
        excludedURLs.insert(removalCandidate.standardizedFileURL)
        exclusionStore.saveExcludedURLs(excludedURLs, for: rootURL)
        self.removalCandidate = nil

        if selectedURL == removalCandidate {
            stopFileWatch()
            openDocumentTabs.removeAll {
                $0.url.standardizedFileURL == removalCandidate.standardizedFileURL
            }
            selectedURL = nil
            selectedDocument = nil
            draftText = ""
            isEditing = false
            isDirty = false
            externalChangeCandidate = nil
            router.navigate(to: .folder(rootURL))
        }
        reloadTree()
    }

    func beginEditing() {
        guard selectedDocument != nil else { return }
        isEditing = true
    }

    func navigateToHeading(_ item: MarkdownOutlineItem) {
        headingNavigationRequest = HeadingNavigationRequest(blockID: item.blockID)
    }

    func toggleFindReplace() {
        showsFindReplace.toggle()
    }

    func closeFindReplace() {
        showsFindReplace = false
    }

    var findMatchCount: Int {
        textSearch.matchCount(in: draftText, query: findText)
    }

    func replaceNextMatch() {
        guard selectedDocument != nil, !findText.isEmpty else { return }
        let updatedText = textSearch.replacingFirst(
            in: draftText,
            query: findText,
            with: replacementText
        )
        guard updatedText != draftText else { return }
        updateDraft(updatedText)
    }

    func replaceAllMatches() {
        guard selectedDocument != nil, !findText.isEmpty else { return }
        let updatedText = textSearch.replacingAll(
            in: draftText,
            query: findText,
            with: replacementText
        )
        guard updatedText != draftText else { return }
        updateDraft(updatedText)
    }

    func insertTableTemplate() {
        guard selectedDocument != nil else { return }
        let separator = draftText.isEmpty || draftText.hasSuffix("\n") ? "" : "\n\n"
        updateDraft(draftText + separator + "| 列 1 | 列 2 |\n| --- | --- |\n| 内容 | 内容 |\n")
    }

    var editableTable: MarkdownTableEditorSession? {
        MarkdownTableEditor().firstTable(in: draftText)
    }

    func openTableEditor() {
        guard editableTable != nil else {
            showError("当前文档中没有可编辑的 Markdown 表格。")
            return
        }
        showsTableEditor = true
    }

    func closeTableEditor() {
        showsTableEditor = false
    }

    func applyTableEditor(_ session: MarkdownTableEditorSession) {
        let updatedText = MarkdownTableEditor().replacingFirstTable(in: draftText, with: session)
        guard updatedText != draftText else {
            showsTableEditor = false
            return
        }
        updateDraft(updatedText)
        showsTableEditor = false
    }

    func toggleTask(_ item: MarkdownTaskItem) {
        guard selectedDocument != nil else { return }
        var lines = draftText.components(separatedBy: "\n")
        guard lines.indices.contains(item.sourceLine) else { return }

        let line = lines[item.sourceLine]
        let pattern = #"^(\s*(?:[-*+]|\d+[.)])\s+)\[([ xX])\]"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: line,
                range: NSRange(location: 0, length: (line as NSString).length)
              ),
              let markerRange = Range(match.range(at: 2), in: line) else {
            return
        }

        let currentMarker = String(line[markerRange])
        let nextMarker = currentMarker.lowercased() == "x" ? " " : "x"
        let fullMarkerRange = Range(match.range, in: line)!
        let fullMarker = String(line[fullMarkerRange])
        let updatedMarker = fullMarker.replacingOccurrences(
            of: "[\(currentMarker)]",
            with: "[\(nextMarker)]"
        )
        lines[item.sourceLine].replaceSubrange(fullMarkerRange, with: updatedMarker)
        updateDraft(lines.joined(separator: "\n"))
    }

    func updateDraft(_ text: String) {
        draftText = text
        isDirty = text != selectedDocument?.source
        scheduleAutoSaveIfNeeded()
    }

    func saveDocument() {
        guard let document = selectedDocument else { return }
        autoSaveTask?.cancel()
        autoSaveTask = nil
        do {
            try fileSystem.writeMarkdown(at: document.url, contents: draftText)
            selectedDocument = try fileSystem.readMarkdown(at: document.url)
            draftText = selectedDocument?.source ?? draftText
            isDirty = false
            ignoredExternalChangeDate = nil
            externalChangeCandidate = nil
            reloadTree(selecting: document.url)
            clearError()
        } catch {
            showError(error.localizedDescription)
        }
    }

    func saveAsDocument() {
        guard let document = selectedDocument else { return }
        guard let destinationURL = filePicker.chooseMarkdownSaveLocation(
            suggestedName: document.url.lastPathComponent
        ) else {
            return
        }

        let markdownURL: URL
        if DocumentSupport.isMarkdownFile(destinationURL) {
            markdownURL = destinationURL
        } else {
            let baseURL = destinationURL.pathExtension.isEmpty
                ? destinationURL
                : destinationURL.deletingPathExtension()
            markdownURL = baseURL.appendingPathExtension("md")
        }
        let wasEditing = isEditing

        do {
            try fileSystem.writeMarkdown(at: markdownURL, contents: draftText)
            openDocument(at: markdownURL)
            if wasEditing {
                beginEditing()
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    func exportHTMLDocument() {
        guard let document = selectedDocument else { return }
        let suggestedName = document.url.deletingPathExtension().lastPathComponent + ".html"
        guard let destinationURL = filePicker.chooseHTMLSaveLocation(suggestedName: suggestedName) else {
            return
        }
        let htmlURL = destinationURL.pathExtension.lowercased() == "html"
            ? destinationURL
            : destinationURL.appendingPathExtension("html")

        do {
            try exportService.writeHTML(
                source: draftText,
                title: document.title,
                baseURL: document.url.deletingLastPathComponent(),
                to: htmlURL
            )
            clearError()
        } catch {
            showError(error.localizedDescription)
        }
    }

    func printDocument() {
        guard selectedDocument != nil else { return }
        guard exportService.printDocument(source: draftText) else {
            showError("无法打开打印面板。")
            return
        }
        clearError()
    }

    func reloadAfterExternalChange() {
        guard externalChangeCandidate != nil else { return }
        externalChangeCandidate = nil
        ignoredExternalChangeDate = nil
        reloadSelectedDocumentFromDisk()
    }

    func keepCurrentDocumentAfterExternalChange() {
        guard let document = selectedDocument else {
            externalChangeCandidate = nil
            return
        }
        ignoredExternalChangeDate = modificationDate(of: document.url)
        externalChangeCandidate = nil
    }

    func finishEditing() {
        if isDirty {
            saveDocument()
        }
        guard !isDirty else { return }
        isEditing = false
    }

    func createNewFile() {
        guard canLeaveCurrentDocument else { return }
        let directory = creationDirectory ?? newDocumentLocationProvider.defaultWorkspaceURL()
        fileNamePromptError = nil
        fileNameInput = "未命名"
        fileNamePrompt = FileNamePrompt(action: .create(directory: directory))
    }

    func createNewFolder() {
        guard canLeaveCurrentDocument else { return }
        guard let directory = creationDirectory else {
            showError("请先打开一个工作区。")
            return
        }

        let url = uniqueURL(in: directory, baseName: "新建文件夹", pathExtension: nil)
        do {
            try fileSystem.createDirectory(at: url)
            reloadTree(selecting: url)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func showDefaultAppInstructions() {
        defaultAppService.openInstructions()
    }

    func clearError() {
        errorMessage = nil
    }

    private var creationDirectory: URL? {
        guard let rootURL else { return nil }
        guard let selectedURL else { return rootURL }
        let selectedValues = try? selectedURL.resourceValues(forKeys: [.isDirectoryKey])
        return selectedValues?.isDirectory == true ? selectedURL : selectedURL.deletingLastPathComponent()
    }

    private func ensureWorkspaceDirectory(at directory: URL) throws -> URL {
        do {
            _ = try fileSystem.tree(for: directory)
        } catch {
            try fileSystem.createDirectory(at: directory)
        }
        return directory
    }

    private func markdownURL(for input: String, in directory: URL) -> URL? {
        var filename = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !filename.isEmpty,
              filename != ".",
              filename != "..",
              !filename.contains("/"),
              !filename.contains("\\"),
              !filename.contains(":") else {
            return nil
        }

        let filenameURL = URL(fileURLWithPath: filename)
        let extensionName = filenameURL.pathExtension.lowercased()
        if DocumentSupport.markdownExtensions.contains(extensionName) {
            filename = filenameURL.deletingPathExtension().lastPathComponent
        }
        guard !filename.isEmpty else { return nil }
        return directory.appendingPathComponent(filename).appendingPathExtension("md")
    }

    private func openWorkspace(at url: URL) {
        guard canLeaveCurrentDocument else { return }
        do {
            stopFileWatch()
            autoSaveTask?.cancel()
            autoSaveTask = nil
            let newTree = try fileSystem.tree(for: url)
            openDocumentTabs.removeAll()
            rootURL = url
            excludedURLs = Set(exclusionStore.excludedURLs(for: url).map { $0.standardizedFileURL })
            tree = excludingRemovedNodes(from: newTree)
            selectedURL = nil
            selectedDocument = nil
            draftText = ""
            showsSourceEditor = false
            isEditing = false
            isDirty = false
            externalChangeCandidate = nil
            ignoredExternalChangeDate = nil
            router.navigate(to: .folder(url))
            clearError()
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func openDocument(at url: URL) {
        guard canLeaveCurrentDocument || selectedURL == url else { return }
        guard DocumentSupport.isMarkdownFile(url) else {
            showError("“\(url.lastPathComponent)”不是支持的 Markdown 文件。")
            return
        }

        do {
            if rootURL == nil || !(url.isDescendant(of: rootURL!) || url == rootURL) {
                rootURL = url.deletingLastPathComponent()
                excludedURLs = Set(exclusionStore.excludedURLs(for: rootURL!).map { $0.standardizedFileURL })
            }
            includeInWorkspace(url)
            tree = excludingRemovedNodes(from: try fileSystem.tree(for: rootURL!))
            let document = try fileSystem.readMarkdown(at: url)
            selectedDocument = document
            draftText = selectedDocument?.source ?? ""
            showsSourceEditor = false
            isEditing = false
            isDirty = false
            externalChangeCandidate = nil
            ignoredExternalChangeDate = nil
            selectedURL = url
            if !openDocumentTabs.contains(where: {
                $0.url.standardizedFileURL == url.standardizedFileURL
            }) {
                openDocumentTabs.append(DocumentTab(document: document))
            }
            recordRecentDocument(url)
            router.navigate(to: .document(url))
            startFileWatch()
            clearError()
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func reloadTree(selecting url: URL? = nil) {
        guard let rootURL else { return }
        do {
            tree = excludingRemovedNodes(from: try fileSystem.tree(for: rootURL))
            if let url {
                selectedURL = url
            }
            clearError()
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func openImplicitWorkspace(at directory: URL, showing documentURL: URL) throws {
        let newTree = try fileSystem.tree(for: directory)
        rootURL = directory
        let documentPath = documentURL.standardizedFileURL
        excludedURLs = Set(markdownURLs(in: newTree).filter {
            $0.standardizedFileURL != documentPath
        }.map { $0.standardizedFileURL })
        tree = excludingRemovedNodes(from: newTree)
        selectedURL = nil
        selectedDocument = nil
        draftText = ""
        showsSourceEditor = false
        isEditing = false
        isDirty = false
        externalChangeCandidate = nil
        ignoredExternalChangeDate = nil
        router.navigate(to: .folder(directory))
    }

    private func markdownURLs(in nodes: [WorkspaceNode]) -> [URL] {
        nodes.flatMap { node in
            node.isFolder ? markdownURLs(in: node.children) : [node.url]
        }
    }

    private func uniqueURL(in directory: URL, baseName: String, pathExtension: String?) -> URL {
        var index = 0
        while true {
            let suffix = index == 0 ? "" : " (\(index + 1))"
            let filename = baseName + suffix + (pathExtension.map { ".\($0)" } ?? "")
            let candidate = directory.appendingPathComponent(filename)
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
    }

    private func scheduleAutoSaveIfNeeded() {
        guard isDirty, selectedDocument != nil else {
            autoSaveTask?.cancel()
            autoSaveTask = nil
            return
        }

        autoSaveTask?.cancel()
        autoSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            self?.saveDocument()
        }
    }

    private func startFileWatch() {
        stopFileWatch()
        fileWatchTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForExternalChange()
            }
        }
    }

    private func stopFileWatch() {
        fileWatchTimer?.invalidate()
        fileWatchTimer = nil
    }

    private func checkForExternalChange() {
        guard let document = selectedDocument,
              let currentDate = modificationDate(of: document.url),
              let knownDate = document.modifiedAt,
              abs(currentDate.timeIntervalSince(knownDate)) > 0.001 else {
            return
        }

        if let ignoredExternalChangeDate,
           abs(currentDate.timeIntervalSince(ignoredExternalChangeDate)) <= 0.001 {
            return
        }

        if isDirty {
            if externalChangeCandidate == nil {
                externalChangeCandidate = document.url
            }
        } else {
            reloadSelectedDocumentFromDisk()
        }
    }

    private func reloadSelectedDocumentFromDisk() {
        guard let document = selectedDocument else { return }
        do {
            let refreshedDocument = try fileSystem.readMarkdown(at: document.url)
            selectedDocument = refreshedDocument
            draftText = refreshedDocument.source
            isDirty = false
            ignoredExternalChangeDate = nil
            clearError()
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private func recordRecentDocument(_ url: URL) {
        let normalizedURL = url.standardizedFileURL
        recentDocumentURLs.removeAll { $0.standardizedFileURL == normalizedURL }
        recentDocumentURLs.insert(normalizedURL, at: 0)
        recentDocumentURLs = Array(recentDocumentURLs.prefix(10))
        persistRecentDocumentURLs()
    }

    private func persistRecentDocumentURLs() {
        UserDefaults.standard.set(recentDocumentURLs.map(\.path), forKey: Self.recentDocumentsDefaultsKey)
    }

    private static func loadRecentDocumentURLs() -> [URL] {
        let paths = UserDefaults.standard.stringArray(forKey: recentDocumentsDefaultsKey) ?? []
        return paths.map { URL(fileURLWithPath: $0) }
            .filter { DocumentSupport.isMarkdownFile($0) }
    }

    private func includingURL(_ url: URL) -> URL {
        url.standardizedFileURL
    }

    private func includeInWorkspace(_ url: URL) {
        guard let rootURL else { return }
        let normalizedURL = includingURL(url)
        guard excludedURLs.remove(normalizedURL) != nil else { return }
        exclusionStore.saveExcludedURLs(excludedURLs, for: rootURL)
    }

    private func excludingRemovedNodes(from nodes: [WorkspaceNode]) -> [WorkspaceNode] {
        nodes.compactMap { node in
            if !node.isFolder {
                return excludedURLs.contains(includingURL(node.url)) ? nil : node
            }
            return WorkspaceNode(
                url: node.url,
                kind: node.kind,
                children: excludingRemovedNodes(from: node.children)
            )
        }
    }

    private var canLeaveCurrentDocument: Bool {
        guard isDirty else { return true }
        showError("当前文档有未保存修改，请先保存后再切换文档。")
        return false
    }
}

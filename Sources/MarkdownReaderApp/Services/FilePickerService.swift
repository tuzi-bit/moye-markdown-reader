import AppKit
import Foundation

protocol FilePickerService {
    func chooseFolder() -> URL?
    func chooseMarkdownFile() -> URL?
    func chooseMarkdownSaveLocation(suggestedName: String) -> URL?
    func chooseHTMLSaveLocation(suggestedName: String) -> URL?
}

struct OpenPanelFilePicker: FilePickerService {
    func chooseFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "选择 Markdown 工作区"
        panel.message = "选择包含 Markdown 文档的文件夹"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    func chooseMarkdownFile() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "打开 Markdown 文件"
        panel.allowedContentTypes = [.plainText]
        panel.allowsOtherFileTypes = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    func chooseMarkdownSaveLocation(suggestedName: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = "另存为 Markdown 文件"
        panel.message = "选择保存位置"
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    func chooseHTMLSaveLocation(suggestedName: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = "导出 HTML"
        panel.message = "选择 HTML 文件保存位置"
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [.html]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        return panel.runModal() == .OK ? panel.url : nil
    }
}

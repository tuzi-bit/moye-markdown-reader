import Foundation

protocol FileSystemService {
    func tree(for directory: URL) throws -> [WorkspaceNode]
    func readMarkdown(at url: URL) throws -> MarkdownDocument
    func createFile(at url: URL, contents: String) throws
    func createDirectory(at url: URL) throws
    func writeMarkdown(at url: URL, contents: String) throws
    func renameMarkdown(at sourceURL: URL, to destinationURL: URL) throws
}

enum FileSystemError: LocalizedError, Equatable {
    case notDirectory(URL)
    case unsupportedFile(URL)
    case unreadableFile(URL)
    case itemAlreadyExists(URL)
    case writeFailed(URL)
    case renameFailed(URL, URL)

    var errorDescription: String? {
        switch self {
        case let .notDirectory(url):
            return "“\(url.lastPathComponent)”不是文件夹。"
        case let .unsupportedFile(url):
            return "“\(url.lastPathComponent)”不是支持的 Markdown 文件。"
        case let .unreadableFile(url):
            return "无法读取“\(url.lastPathComponent)”，请确认文件编码和访问权限。"
        case let .itemAlreadyExists(url):
            return "“\(url.lastPathComponent)”已经存在。"
        case let .writeFailed(url):
            return "无法保存“\(url.lastPathComponent)”，请确认文件没有被其他程序锁定且当前用户有写入权限。"
        case let .renameFailed(source, destination):
            return "无法将“\(source.lastPathComponent)”重命名为“\(destination.lastPathComponent)”，请确认文件没有被其他程序占用且当前用户有写入权限。"
        }
    }
}

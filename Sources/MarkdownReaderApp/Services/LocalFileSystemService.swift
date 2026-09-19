import Foundation

struct LocalFileSystemService: FileSystemService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func tree(for directory: URL) throws -> [WorkspaceNode] {
        guard isDirectory(directory) else {
            throw FileSystemError.notDirectory(directory)
        }

        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isHiddenKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )

        return urls.compactMap(buildNode(at:)).sorted(by: WorkspaceNode.sorting)
    }

    func readMarkdown(at url: URL) throws -> MarkdownDocument {
        guard DocumentSupport.isMarkdownFile(url) else {
            throw FileSystemError.unsupportedFile(url)
        }

        let source: String
        do {
            source = try String(contentsOf: url, encoding: .utf8)
        } catch {
            guard let data = try? Data(contentsOf: url),
                  let decoded = String(data: data, encoding: .utf16)
            else {
                throw FileSystemError.unreadableFile(url)
            }
            source = decoded
        }

        let modifiedAt = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate
        return MarkdownDocument(url: url, source: source, modifiedAt: modifiedAt ?? nil)
    }

    func createFile(at url: URL, contents: String = "") throws {
        guard !fileManager.fileExists(atPath: url.path) else {
            throw FileSystemError.itemAlreadyExists(url)
        }
        guard fileManager.createFile(atPath: url.path, contents: contents.data(using: .utf8)) else {
            throw FileSystemError.unreadableFile(url)
        }
    }

    func createDirectory(at url: URL) throws {
        guard !fileManager.fileExists(atPath: url.path) else {
            throw FileSystemError.itemAlreadyExists(url)
        }
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: false)
        } catch {
            throw FileSystemError.unreadableFile(url)
        }
    }

    func writeMarkdown(at url: URL, contents: String) throws {
        guard DocumentSupport.isMarkdownFile(url) else {
            throw FileSystemError.unsupportedFile(url)
        }
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw FileSystemError.writeFailed(url)
        }
    }

    func renameMarkdown(at sourceURL: URL, to destinationURL: URL) throws {
        guard DocumentSupport.isMarkdownFile(sourceURL), DocumentSupport.isMarkdownFile(destinationURL) else {
            throw FileSystemError.unsupportedFile(sourceURL)
        }
        guard !fileManager.fileExists(atPath: destinationURL.path) else {
            throw FileSystemError.itemAlreadyExists(destinationURL)
        }
        do {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        } catch {
            throw FileSystemError.renameFailed(sourceURL, destinationURL)
        }
    }

    private func buildNode(at url: URL) -> WorkspaceNode? {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values?.isSymbolicLink != true else { return nil }
        if values?.isDirectory == true {
            let children = (try? tree(for: url)) ?? []
            return WorkspaceNode(url: url, kind: .folder, children: children)
        }
        guard values?.isRegularFile == true, DocumentSupport.isMarkdownFile(url) else {
            return nil
        }
        return WorkspaceNode(url: url, kind: .markdownFile, children: [])
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}

extension WorkspaceNode {
    static func sorting(_ lhs: WorkspaceNode, _ rhs: WorkspaceNode) -> Bool {
        if lhs.isFolder != rhs.isFolder {
            return lhs.isFolder
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}

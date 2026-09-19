import Foundation

enum WorkspaceNodeKind: Hashable {
    case folder
    case markdownFile
}

struct WorkspaceNode: Identifiable, Hashable {
    let url: URL
    let kind: WorkspaceNodeKind
    let children: [WorkspaceNode]

    var id: URL { url }
    var name: String { url.lastPathComponent }
    var isFolder: Bool { kind == .folder }
    var optionalChildren: [WorkspaceNode]? {
        children.isEmpty ? nil : children
    }

    func filtered(matching query: String) -> WorkspaceNode? {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        guard !normalizedQuery.isEmpty else { return self }

        let matchingChildren = children.compactMap { $0.filtered(matching: normalizedQuery) }
        let matchesSelf = name.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        ).localizedCaseInsensitiveContains(normalizedQuery)

        guard matchesSelf || !matchingChildren.isEmpty else { return nil }
        return WorkspaceNode(url: url, kind: kind, children: matchingChildren)
    }
}

enum DocumentSupport {
    static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkdn"]

    static func isMarkdownFile(_ url: URL) -> Bool {
        markdownExtensions.contains(url.pathExtension.lowercased())
    }
}

extension URL {
    func isDescendant(of directory: URL) -> Bool {
        let directoryPath = directory.standardizedFileURL.path
        let candidatePath = standardizedFileURL.path
        guard candidatePath != directoryPath else { return false }
        return candidatePath.hasPrefix(directoryPath + "/")
    }
}

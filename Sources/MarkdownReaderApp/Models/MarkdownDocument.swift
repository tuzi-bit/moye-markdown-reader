import Foundation

struct MarkdownDocument: Identifiable, Equatable {
    let url: URL
    let source: String
    let modifiedAt: Date?

    var id: URL { url }
    var title: String {
        let filename = url.deletingPathExtension().lastPathComponent
        return filename.isEmpty ? "未命名文档" : filename
    }
}

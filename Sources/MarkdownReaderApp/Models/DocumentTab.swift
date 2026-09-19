import Foundation

struct DocumentTab: Identifiable, Equatable {
    let url: URL
    let title: String

    var id: URL { url }

    init(document: MarkdownDocument) {
        url = document.url
        title = document.title
    }
}

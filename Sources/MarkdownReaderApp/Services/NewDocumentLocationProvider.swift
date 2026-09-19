import Foundation

protocol NewDocumentLocationProviding {
    func defaultWorkspaceURL() -> URL
}

struct DocumentsNewDocumentLocationProvider: NewDocumentLocationProviding {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func defaultWorkspaceURL() -> URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        return documentsURL.appendingPathComponent("Markdown Reader", isDirectory: true)
    }
}

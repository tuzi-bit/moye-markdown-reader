import AppKit
import Foundation

extension Notification.Name {
    static let markdownReaderDidReceiveURLs = Notification.Name("MarkdownReader.didReceiveURLs")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pendingURLs: [URL] = []

    func application(_ application: NSApplication, open urls: [URL]) {
        pendingURLs.append(contentsOf: urls)
        NotificationCenter.default.post(
            name: .markdownReaderDidReceiveURLs,
            object: urls
        )
    }

    func applicationShouldHandleReopen(
        _ application: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        application.activate(ignoringOtherApps: true)

        guard !flag else { return true }

        // WindowGroup can keep a window in the app even when it is hidden or
        // minimized. Restore the existing document window before letting
        // AppKit handle the reopen request. Do not activate SwiftUI's empty
        // placeholder window: when the last window was closed, WindowGroup
        // must create a fresh content window instead.
        DispatchQueue.main.async {
            guard let window = application.windows.first(where: {
                $0.title == "墨页"
                    && $0.canBecomeKey
                    && $0.styleMask.contains(.titled)
                    && !($0 is NSPanel)
            }) else {
                return
            }

            if window.isMiniaturized {
                window.deminiaturize(application)
            }
            window.makeKeyAndOrderFront(application)
        }

        return true
    }

    func takePendingURLs() -> [URL] {
        defer { pendingURLs.removeAll() }
        return pendingURLs
    }
}

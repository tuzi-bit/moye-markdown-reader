import AppKit
import Foundation

struct DefaultAppService {
    func openInstructions() {
        let alert = NSAlert()
        alert.messageText = "将墨页设为默认打开方式"
        alert.informativeText = "在 Finder 中选中任意 .md 文件，右键选择“显示简介”，在“打开方式”中选择墨页，然后点击“全部更改…”。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }
}

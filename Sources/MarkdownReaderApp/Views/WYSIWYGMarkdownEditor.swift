import AppKit
import SwiftUI

struct WYSIWYGMarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.drawsBackground = false
        textView.focusRingType = .none
        textView.textContainerInset = NSSize(width: 12, height: 18)
        textView.font = NSFont.systemFont(ofSize: 17)
        textView.textColor = NSColor.textColor
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textStorage?.setAttributedString(MarkdownFormatting.styledEditorText(text))

        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        }
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        let appearanceName: NSAppearance.Name = colorScheme == .dark ? .darkAqua : .aqua
        scrollView.appearance = NSAppearance(named: appearanceName)

        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.appearance = NSAppearance(named: appearanceName)
        textView.textColor = .labelColor
        guard textView.string != text else { return }

        let selectedRange = textView.selectedRange()
        context.coordinator.isApplyingAttributes = true
        textView.textStorage?.setAttributedString(MarkdownFormatting.styledEditorText(text))
        context.coordinator.isApplyingAttributes = false
        textView.setSelectedRange(NSRange(
            location: min(selectedRange.location, (text as NSString).length),
            length: 0
        ))
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: WYSIWYGMarkdownEditor
        var isApplyingAttributes = false

        init(_ parent: WYSIWYGMarkdownEditor) {
            self.parent = parent
        }

        func textView(
            _ textView: NSTextView,
            shouldChangeTextIn affectedCharRange: NSRange,
            replacementString: String?
        ) -> Bool {
            guard !isApplyingAttributes,
                  affectedCharRange.length == 0,
                  let replacementString,
                  replacementString == "\n" || replacementString == "\r",
                  let continuation = listContinuation(
                    in: textView.string,
                    cursorLocation: affectedCharRange.location
                  ) else {
                return true
            }

            isApplyingAttributes = true
            textView.insertText("\n" + continuation, replacementRange: affectedCharRange)
            isApplyingAttributes = false
            parent.text = textView.string
            restyle(textView)
            return false
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingAttributes,
                  let textView = notification.object as? NSTextView
            else { return }

            let selectedRange = textView.selectedRange()
            parent.text = textView.string
            restyle(textView, selectedRange: selectedRange)
        }

        private func restyle(_ textView: NSTextView, selectedRange: NSRange? = nil) {
            let range = selectedRange ?? textView.selectedRange()
            isApplyingAttributes = true
            textView.textStorage?.setAttributedString(MarkdownFormatting.styledEditorText(textView.string))
            isApplyingAttributes = false
            textView.setSelectedRange(NSRange(
                location: min(range.location, (textView.string as NSString).length),
                length: 0
            ))
        }

        private func listContinuation(in source: String, cursorLocation: Int) -> String? {
            let nsSource = source as NSString
            let safeCursor = min(max(0, cursorLocation), nsSource.length)
            let prefix = nsSource.substring(with: NSRange(location: 0, length: safeCursor))
            let lineStart = prefix.lastIndex(of: "\n").map { prefix.index(after: $0) } ?? prefix.startIndex
            let currentLine = String(prefix[lineStart...])

            let unorderedPattern = #"^(\s*)([-*+])\s+(?:(\[[ xX]\])\s+)?(.+)$"#
            if let match = firstMatch(unorderedPattern, in: currentLine),
               let indentation = capture(1, from: match, in: currentLine),
               let marker = capture(2, from: match, in: currentLine),
               let taskMarker = capture(3, from: match, in: currentLine) {
                return "\(indentation)\(marker) \(taskMarker) "
            }
            if let match = firstMatch(unorderedPattern, in: currentLine),
               let indentation = capture(1, from: match, in: currentLine),
               let marker = capture(2, from: match, in: currentLine) {
                return "\(indentation)\(marker) "
            }

            let orderedPattern = #"^(\s*)(\d+)[.)]\s+(.+)$"#
            if let match = firstMatch(orderedPattern, in: currentLine),
               let indentation = capture(1, from: match, in: currentLine),
               let numberText = capture(2, from: match, in: currentLine),
               let number = Int(numberText) {
                return "\(indentation)\(number + 1). "
            }
            return nil
        }

        private func firstMatch(_ pattern: String, in string: String) -> NSTextCheckingResult? {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
            return expression.firstMatch(
                in: string,
                range: NSRange(location: 0, length: (string as NSString).length)
            )
        }

        private func capture(
            _ index: Int,
            from match: NSTextCheckingResult,
            in string: String
        ) -> String? {
            guard match.range(at: index).location != NSNotFound,
                  let range = Range(match.range(at: index), in: string) else {
                return nil
            }
            return String(string[range])
        }
    }
}

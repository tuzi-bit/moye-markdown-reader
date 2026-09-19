import AppKit
import SwiftUI

struct MarkdownPreviewView: View {
    @Binding var source: String
    let baseURL: URL
    let scrollRequest: HeadingNavigationRequest?
    let onToggleTask: (MarkdownTaskItem) -> Void
    private let renderer = MarkdownRenderer()

    init(
        source: Binding<String>,
        baseURL: URL,
        scrollRequest: HeadingNavigationRequest? = nil,
        onToggleTask: @escaping (MarkdownTaskItem) -> Void = { _ in }
    ) {
        _source = source
        self.baseURL = baseURL
        self.scrollRequest = scrollRequest
        self.onToggleTask = onToggleTask
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(renderer.blocks(from: source)) { block in
                        MarkdownBlockView(
                            block: block,
                            renderer: renderer,
                            baseURL: baseURL,
                            onToggleTask: onToggleTask
                        )
                        .id(block.id)
                    }
                }
                .frame(maxWidth: 920, alignment: .leading)
                .padding(.horizontal, 48)
                .padding(.vertical, 38)
            }
            .onChange(of: scrollRequest?.id) { _ in
                guard let scrollRequest else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(scrollRequest.blockID, anchor: .top)
                }
            }
        }
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownBlock
    let renderer: MarkdownRenderer
    let baseURL: URL
    let onToggleTask: (MarkdownTaskItem) -> Void

    var body: some View {
        switch block.kind {
        case let .heading(level, text):
            Text(renderer.renderInline(text))
                .font(.system(size: headingSize(for: level), weight: .bold, design: .rounded))
                .padding(.top, level == 1 ? 4 : 0)

        case let .paragraph(text):
            Text(renderer.renderInline(text))
                .font(.system(size: 17, design: .serif))
                .lineSpacing(5)
                .textSelection(.enabled)

        case let .unorderedList(items):
            listView(items: items, ordered: false)

        case let .orderedList(items):
            listView(items: items, ordered: true)

        case let .taskList(items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items) { item in
                    Button {
                        onToggleTask(item)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            if item.isChecked {
                                Image(systemName: "checkmark.square.fill")
                                    .foregroundStyle(.tint)
                            } else {
                                Image(systemName: "square")
                                    .foregroundStyle(.secondary)
                            }
                            Text(renderer.renderInline(item.text))
                                .font(.system(size: 17, design: .serif))
                                .lineSpacing(4)
                                .strikethrough(item.isChecked, color: .secondary)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }

        case let .quote(text):
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.65))
                    .frame(width: 4)
                Text(renderer.renderInline(text))
                    .font(.system(size: 16, design: .serif))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 4)

        case let .code(language, text):
            VStack(alignment: .leading, spacing: 6) {
                if let language, !language.isEmpty {
                    Text(language)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                ScrollView(.horizontal) {
                    Text(text)
                        .font(.system(size: 14, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            }

        case let .math(expression):
            MathBlockView(expression: expression)

        case let .mermaid(source):
            MermaidDiagramView(source: source)

        case let .table(headers, rows):
            MarkdownTableView(headers: headers, rows: rows, renderer: renderer)

        case let .image(image):
            MarkdownImageView(image: image, baseURL: baseURL)

        case .divider:
            Divider()
        }
    }

    @ViewBuilder
    private func listView(items: [String], ordered: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(ordered ? "\(index + 1)." : "•")
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .frame(width: ordered ? 24 : 12, alignment: .trailing)
                    Text(renderer.renderInline(item))
                        .font(.system(size: 17, design: .serif))
                        .lineSpacing(4)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func headingSize(for level: Int) -> CGFloat {
        switch level {
        case 1: return 30
        case 2: return 25
        case 3: return 21
        default: return 18
        }
    }
}

private struct MarkdownImageView: View {
    let image: MarkdownImage
    let baseURL: URL

    private var localImage: NSImage? {
        guard !image.source.hasPrefix("http://"), !image.source.hasPrefix("https://") else {
            return nil
        }
        let path = (image.source as NSString).expandingTildeInPath
        let url = (path.hasPrefix("/")
            ? URL(fileURLWithPath: path)
            : baseURL.appendingPathComponent(path)).standardizedFileURL
        return NSImage(contentsOf: url)
    }

    private var remoteURL: URL? {
        guard let url = URL(string: image.source),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }
        return url
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let localImage {
                Image(nsImage: localImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 820, maxHeight: 560, alignment: .leading)
            } else if let remoteURL {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 820, maxHeight: 560, alignment: .leading)
                    case .failure:
                        unavailableImage
                    case .empty:
                        ProgressView()
                            .frame(width: 120, height: 80)
                    @unknown default:
                        unavailableImage
                    }
                }
            } else {
                unavailableImage
            }

            if !image.altText.isEmpty {
                Text(image.altText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var unavailableImage: some View {
        Label("无法加载图片：\(image.source)", systemImage: "photo")
            .foregroundStyle(.secondary)
            .padding(18)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MathBlockView: View {
    let expression: String
    private let renderer = MathExpressionRenderer()

    var body: some View {
        ScrollView(.horizontal) {
            Text(renderer.displayText(for: expression))
                .font(.system(size: 19, design: .serif))
                .textSelection(.enabled)
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.18))
        }
    }
}

private struct MermaidDiagramView: View {
    let source: String

    var body: some View {
        if let diagram = MermaidDiagram.parse(source) {
            diagramView(diagram)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label("无法解析 Mermaid 图示，显示源码", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(source)
                    .font(.system(size: 14, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private func diagramView(_ diagram: MermaidDiagram) -> some View {
        let isHorizontal = diagram.direction == .horizontal
        ScrollView(isHorizontal ? .horizontal : .vertical) {
            if isHorizontal {
                HStack(spacing: 12) {
                    diagramNodes(diagram.nodes, direction: .horizontal)
                }
                .padding(20)
            } else {
                VStack(spacing: 12) {
                    diagramNodes(diagram.nodes, direction: .vertical)
                }
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.25))
        }
    }

    @ViewBuilder
    private func diagramNodes(
        _ nodes: [MermaidDiagram.Node],
        direction: MermaidDiagram.Direction
    ) -> some View {
        ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
            MermaidNodeView(label: node.label)
            if index < nodes.count - 1 {
                Image(systemName: direction == .horizontal ? "arrow.right" : "arrow.down")
                    .foregroundStyle(.tint)
            }
        }
    }
}

private struct MermaidNodeView: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 15, weight: .medium))
            .multilineTextAlignment(.center)
            .frame(minWidth: 120, minHeight: 46)
            .padding(.horizontal, 12)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.accentColor.opacity(0.55), lineWidth: 1)
            }
    }
}

private struct MarkdownTableView: View {
    let headers: [String]
    let rows: [[String]]
    let renderer: MarkdownRenderer

    private var columnCount: Int {
        max(headers.count, rows.map(\.count).max() ?? 0)
    }

    var body: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 0) {
                tableRow(headers, header: true)
                Divider()
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    tableRow(row, header: false)
                    Divider()
                }
            }
            .frame(minWidth: 640, alignment: .leading)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.18))
        }
    }

    private func tableRow(_ cells: [String], header: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0..<columnCount, id: \.self) { index in
                Text(renderer.renderInline(index < cells.count ? cells[index] : ""))
                    .font(.system(size: 15, weight: header ? .semibold : .regular, design: .serif))
                    .lineSpacing(3)
                    .frame(minWidth: 130, maxWidth: 280, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
            }
        }
        .background(header ? Color.secondary.opacity(0.1) : Color.clear)
    }
}

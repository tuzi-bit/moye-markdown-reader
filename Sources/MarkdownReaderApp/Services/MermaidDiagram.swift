import Foundation

struct MermaidDiagram: Equatable {
    enum Direction: Equatable {
        case horizontal
        case vertical
    }

    struct Node: Identifiable, Equatable {
        let id: String
        let label: String
    }

    let direction: Direction
    let nodes: [Node]

    static func parse(_ source: String) -> MermaidDiagram? {
        let lines = source
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("%%") }
        guard !lines.isEmpty else { return nil }

        let direction: Direction = lines.first?.localizedCaseInsensitiveContains(" LR") == true
            ? .horizontal
            : .vertical
        var nodes: [Node] = []
        var seenIDs = Set<String>()

        for line in lines.dropFirst() {
            let endpoints = line.components(separatedBy: "-->")
            guard endpoints.count >= 2 else { continue }
            for endpoint in endpoints {
                guard let node = parseNode(endpoint) else { continue }
                if seenIDs.insert(node.id).inserted {
                    nodes.append(node)
                }
            }
        }

        guard nodes.count >= 2 else { return nil }
        return MermaidDiagram(direction: direction, nodes: nodes)
    }

    private static func parseNode(_ value: String) -> Node? {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
        let pattern = #"^([A-Za-z0-9_-]+)(?:\[([^\]]+)\]|\(([^\)]+)\)|\{([^\}]+)\})?"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: trimmed,
                range: NSRange(location: 0, length: (trimmed as NSString).length)
              ),
              let idRange = Range(match.range(at: 1), in: trimmed) else {
            return nil
        }

        let id = String(trimmed[idRange])
        let labelRange = [2, 3, 4]
            .compactMap { index -> Range<String.Index>? in
                guard match.range(at: index).location != NSNotFound else { return nil }
                return Range(match.range(at: index), in: trimmed)
            }
            .first
        return Node(id: id, label: labelRange.map { String(trimmed[$0]) } ?? id)
    }
}

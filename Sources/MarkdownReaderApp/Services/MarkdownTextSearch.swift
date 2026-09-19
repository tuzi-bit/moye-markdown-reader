import Foundation

struct MarkdownTextSearch {
    func matchCount(in source: String, query: String) -> Int {
        ranges(in: source, query: query).count
    }

    func replacingFirst(in source: String, query: String, with replacement: String) -> String {
        guard let range = ranges(in: source, query: query).first else { return source }
        var result = source
        result.replaceSubrange(range, with: replacement)
        return result
    }

    func replacingAll(in source: String, query: String, with replacement: String) -> String {
        guard !query.isEmpty else { return source }
        return source.replacingOccurrences(
            of: query,
            with: replacement,
            options: [.caseInsensitive],
            range: source.startIndex..<source.endIndex
        )
    }

    private func ranges(in source: String, query: String) -> [Range<String.Index>] {
        guard !query.isEmpty else { return [] }

        var results: [Range<String.Index>] = []
        var searchStart = source.startIndex
        while searchStart < source.endIndex,
              let range = source.range(
                of: query,
                options: [.caseInsensitive],
                range: searchStart..<source.endIndex
              ) {
            results.append(range)
            searchStart = range.upperBound
        }
        return results
    }
}

import Foundation

protocol WorkspaceExclusionStore {
    func excludedURLs(for workspace: URL) -> Set<URL>
    func saveExcludedURLs(_ urls: Set<URL>, for workspace: URL)
}

struct UserDefaultsWorkspaceExclusionStore: WorkspaceExclusionStore {
    private let defaults: UserDefaults
    private let storageKey = "MarkdownReader.workspaceExclusions"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func excludedURLs(for workspace: URL) -> Set<URL> {
        guard let data = defaults.data(forKey: storageKey),
              let values = try? JSONDecoder().decode([String: Set<URL>].self, from: data)
        else {
            return []
        }
        return values[workspaceKey(workspace)] ?? []
    }

    func saveExcludedURLs(_ urls: Set<URL>, for workspace: URL) {
        var values = decodedValues()
        let key = workspaceKey(workspace)
        if urls.isEmpty {
            values.removeValue(forKey: key)
        } else {
            values[key] = urls
        }
        guard let data = try? JSONEncoder().encode(values) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func decodedValues() -> [String: Set<URL>] {
        guard let data = defaults.data(forKey: storageKey),
              let values = try? JSONDecoder().decode([String: Set<URL>].self, from: data)
        else {
            return [:]
        }
        return values
    }

    private func workspaceKey(_ workspace: URL) -> String {
        workspace.standardizedFileURL.path
    }
}

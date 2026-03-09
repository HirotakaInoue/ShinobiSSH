import Foundation

final class ConnectionStore {
    private let fileURL: URL

    init() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("shinobishsh")
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        self.fileURL = configDir.appendingPathComponent("connections.json")
    }

    func load() -> [SSHConnection] {
        guard let data = try? Data(contentsOf: fileURL),
              let connections = try? JSONDecoder().decode([SSHConnection].self, from: data) else {
            return []
        }
        return connections
    }

    func save(_ connections: [SSHConnection]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(connections) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

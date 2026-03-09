import Foundation

struct SSHProcess: Identifiable, Hashable {
    let id: Int
    let pid: Int
    let command: String
    let host: String
    let user: String
    let port: Int
    var matchedConnectionID: UUID?

    init(pid: Int, command: String) {
        self.id = pid
        self.pid = pid
        self.command = command

        let parsed = SSHProcess.parseSSHCommand(command)
        self.host = parsed.host
        self.user = parsed.user
        self.port = parsed.port
        self.matchedConnectionID = nil
    }

    var displayName: String {
        if user.isEmpty {
            return host
        }
        return "\(user)@\(host)"
    }

    private static func parseSSHCommand(_ command: String) -> (host: String, user: String, port: Int) {
        let parts = command.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        var host = ""
        var user = ""
        var port = 22
        var skipNext = false

        for (index, part) in parts.enumerated() {
            if skipNext {
                skipNext = false
                continue
            }

            if part == "-l" {
                if index + 1 < parts.count {
                    user = parts[index + 1]
                    skipNext = true
                }
            } else if part == "-p" {
                if index + 1 < parts.count {
                    port = Int(parts[index + 1]) ?? 22
                    skipNext = true
                }
            } else if part == "-i" || part == "-o" || part == "-F"
                        || part == "-J" || part == "-W" || part == "-w"
                        || part == "-L" || part == "-R" || part == "-D"
                        || part == "-E" || part == "-S" || part == "-b"
                        || part == "-c" || part == "-e" || part == "-m"
                        || part == "-O" || part == "-Q" {
                skipNext = true
            } else if part.hasPrefix("-") {
                continue
            } else if part.hasSuffix("ssh") || part.hasSuffix("ssh:") {
                continue
            } else if host.isEmpty {
                if part.contains("@") {
                    let components = part.split(separator: "@", maxSplits: 1)
                    if components.count == 2 {
                        user = String(components[0])
                        host = String(components[1])
                    }
                } else {
                    host = part
                }
            }
        }

        return (host, user, port)
    }
}

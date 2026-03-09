import Foundation

struct SSHConnection: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var host: String
    var user: String
    var port: Int
    var identityFile: String?

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        user: String = "",
        port: Int = 22,
        identityFile: String? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.user = user
        self.port = port
        self.identityFile = identityFile
    }

    var displayHost: String {
        if user.isEmpty {
            return port == 22 ? host : "\(host):\(port)"
        }
        return port == 22 ? "\(user)@\(host)" : "\(user)@\(host):\(port)"
    }

    var sshCommand: [String] {
        var args = ["/usr/bin/ssh"]
        if !user.isEmpty {
            args += ["-l", user]
        }
        if port != 22 {
            args += ["-p", String(port)]
        }
        if let key = identityFile, !key.isEmpty {
            args += ["-i", (key as NSString).expandingTildeInPath]
        }
        args.append(host)
        return args
    }
}

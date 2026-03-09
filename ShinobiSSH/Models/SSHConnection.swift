import Foundation

struct LocalForward: Codable, Hashable, Identifiable {
    let id: UUID
    var localPort: Int
    var remoteHost: String
    var remotePort: Int

    init(id: UUID = UUID(), localPort: Int = 0, remoteHost: String = "localhost", remotePort: Int = 0) {
        self.id = id
        self.localPort = localPort
        self.remoteHost = remoteHost
        self.remotePort = remotePort
    }

    var argumentValue: String {
        "\(localPort):\(remoteHost):\(remotePort)"
    }

    var displayString: String {
        "L:\(localPort)\u{2192}\(remoteHost):\(remotePort)"
    }
}

struct SSHConnection: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var host: String
    var user: String
    var port: Int
    var identityFile: String?
    var localForwards: [LocalForward]
    var noRemoteCommand: Bool
    var forceIPv4: Bool

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        user: String = "",
        port: Int = 22,
        identityFile: String? = nil,
        localForwards: [LocalForward] = [],
        noRemoteCommand: Bool = false,
        forceIPv4: Bool = false
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.user = user
        self.port = port
        self.identityFile = identityFile
        self.localForwards = localForwards
        self.noRemoteCommand = noRemoteCommand
        self.forceIPv4 = forceIPv4
    }

    var displayHost: String {
        if user.isEmpty {
            return port == 22 ? host : "\(host):\(port)"
        }
        return port == 22 ? "\(user)@\(host)" : "\(user)@\(host):\(port)"
    }

    var forwardingSummary: String? {
        guard !localForwards.isEmpty else { return nil }
        return localForwards.map { $0.displayString }.joined(separator: ", ")
    }

    var sshCommand: [String] {
        var args = ["/usr/bin/ssh"]
        if forceIPv4 {
            args.append("-4")
        }
        if noRemoteCommand {
            args.append("-N")
        }
        if !user.isEmpty {
            args += ["-l", user]
        }
        if port != 22 {
            args += ["-p", String(port)]
        }
        if let key = identityFile, !key.isEmpty {
            args += ["-i", (key as NSString).expandingTildeInPath]
        }
        for forward in localForwards {
            args += ["-L", forward.argumentValue]
        }
        args.append(host)
        return args
    }
}

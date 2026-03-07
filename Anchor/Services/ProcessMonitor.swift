import Foundation

final class ProcessMonitor {

    func fetchSSHProcesses() -> [SSHProcess] {
        let output = shell("/bin/ps", arguments: ["-eo", "pid,command"])
        var processes: [SSHProcess] = []

        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            guard isSSHClientProcess(trimmed) else { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 1)
            guard parts.count == 2, let pid = Int(parts[0]) else { continue }

            let command = String(parts[1])
            let process = SSHProcess(pid: pid, command: command)

            guard !process.host.isEmpty else { continue }
            processes.append(process)
        }

        return processes
    }

    func terminateProcess(pid: Int) -> Bool {
        kill(Int32(pid), SIGTERM)
        usleep(200_000)

        if kill(Int32(pid), 0) == 0 {
            kill(Int32(pid), SIGKILL)
        }
        return true
    }

    func launchSSH(connection: SSHConnection) -> Int32? {
        let args = connection.sshCommand
        guard args.count >= 2 else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: args[0])
        process.arguments = Array(args.dropFirst())

        let termApp = terminalApp()
        if let app = termApp {
            return launchInTerminal(app: app, connection: connection)
        }

        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            return process.processIdentifier
        } catch {
            return nil
        }
    }

    private func launchInTerminal(app: String, connection: SSHConnection) -> Int32? {
        let sshArgs = connection.sshCommand
        let sshCommand = sshArgs.map { arg in
            arg.contains(" ") ? "'\(arg)'" : arg
        }.joined(separator: " ")

        let script: String
        if app == "Terminal" {
            script = """
            tell application "Terminal"
                activate
                do script "\(sshCommand)"
            end tell
            """
        } else if app == "iTerm" {
            script = """
            tell application "iTerm"
                activate
                create window with default profile command "\(sshCommand)"
            end tell
            """
        } else {
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return 0
        } catch {
            return nil
        }
    }

    private func terminalApp() -> String? {
        let apps = ["iTerm", "Terminal"]
        for app in apps {
            let check = shell("/usr/bin/osascript", arguments: [
                "-e", "tell application \"System Events\" to (name of processes) contains \"\(app)\""
            ])
            if check.trimmingCharacters(in: .whitespacesAndNewlines) == "true" {
                return app
            }
        }
        return "Terminal"
    }

    private func isSSHClientProcess(_ line: String) -> Bool {
        let lower = line.lowercased()
        guard lower.contains("ssh") else { return false }
        guard !lower.contains("sshd") else { return false }
        guard !lower.contains("ssh-agent") else { return false }
        guard !lower.contains("ssh-add") else { return false }
        guard !lower.contains("ssh-keygen") else { return false }
        guard !lower.contains("ssh-keyscan") else { return false }

        let parts = line.split(separator: " ", maxSplits: 1)
        guard parts.count == 2 else { return false }
        let command = String(parts[1])

        let commandParts = command.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard let executable = commandParts.first else { return false }

        return executable.hasSuffix("ssh") || executable.hasSuffix("/ssh")
    }

    private func shell(_ command: String, arguments: [String] = []) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

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

        for _ in 0..<10 {
            usleep(50_000) // 50ms intervals, total max 500ms
            if kill(Int32(pid), 0) != 0 { return true }
        }

        kill(Int32(pid), SIGKILL)
        return true
    }

    func launchSSH(connection: SSHConnection) -> Int32? {
        let termApp = terminalApp()
        return launchInTerminal(app: termApp, connection: connection)
    }

    func launchSSHBackground(connection: SSHConnection) -> Int32? {
        let args = connection.sshCommand
        let process = Process()
        process.executableURL = URL(fileURLWithPath: args[0])
        process.arguments = Array(args.dropFirst())
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            return Int32(process.processIdentifier)
        } catch {
            return nil
        }
    }

    private func launchInTerminal(app: String, connection: SSHConnection) -> Int32? {
        let sshArgs = connection.sshCommand
        let sshCommand = sshArgs.map { escapeForAppleScript($0) }.joined(separator: " ")

        let script: String
        if app == "iTerm" {
            script = """
            tell application "iTerm"
                activate
                create window with default profile command "\(sshCommand)"
            end tell
            """
        } else {
            script = """
            tell application "Terminal"
                activate
                do script "\(sshCommand)"
            end tell
            """
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0 ? 0 : nil
        } catch {
            return nil
        }
    }

    private func escapeForAppleScript(_ arg: String) -> String {
        let escaped = arg
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        if arg.contains(" ") {
            return "'\(arg.replacingOccurrences(of: "'", with: "'\\''"))'"
        }
        return escaped
    }

    private func terminalApp() -> String {
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
        } catch {
            return ""
        }

        // Read data before waitUntilExit to avoid pipe buffer deadlock
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return String(data: data, encoding: .utf8) ?? ""
    }
}

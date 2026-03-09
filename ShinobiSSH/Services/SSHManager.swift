import Foundation
import Combine

final class SSHManager: ObservableObject {
    @Published var savedConnections: [SSHConnection] = []
    @Published var activeProcesses: [SSHProcess] = []
    @Published var lastError: String?

    private let store = ConnectionStore()
    private let monitor = ProcessMonitor()
    private var timer: Timer?
    private let backgroundQueue = DispatchQueue(label: "com.shinobishsh.process-monitor", qos: .utility)

    var activeCount: Int {
        activeProcesses.count
    }

    var matchedProcesses: [SSHProcess] {
        activeProcesses.filter { $0.matchedConnectionID != nil }
    }

    var unmatchedProcesses: [SSHProcess] {
        activeProcesses.filter { $0.matchedConnectionID == nil }
    }

    init() {
        savedConnections = store.load()
        refreshProcesses()
        startMonitoring()
    }

    deinit {
        timer?.invalidate()
    }

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.refreshProcesses()
        }
    }

    func refreshProcesses() {
        let connections = savedConnections
        backgroundQueue.async { [weak self] in
            guard let self else { return }
            var processes = self.monitor.fetchSSHProcesses()

            for i in processes.indices {
                if let match = self.findMatchingConnection(for: processes[i], in: connections) {
                    processes[i].matchedConnectionID = match.id
                }
            }

            DispatchQueue.main.async {
                self.activeProcesses = processes
            }
        }
    }

    private func findMatchingConnection(for process: SSHProcess, in connections: [SSHConnection]) -> SSHConnection? {
        connections.first { conn in
            let hostMatch = conn.host == process.host
            let userMatch = conn.user.isEmpty || conn.user == process.user
            let portMatch = conn.port == process.port
            let forwardMatch = Set(conn.localForwards.map { $0.argumentValue })
                == Set(process.localForwards.map { $0.argumentValue })
            return hostMatch && userMatch && portMatch && forwardMatch
        }
    }

    // MARK: - Connection Management

    func addConnection(_ connection: SSHConnection) {
        savedConnections.append(connection)
        store.save(savedConnections)
    }

    func updateConnection(_ connection: SSHConnection) {
        if let index = savedConnections.firstIndex(where: { $0.id == connection.id }) {
            savedConnections[index] = connection
            store.save(savedConnections)
        }
    }

    func deleteConnection(_ connection: SSHConnection) {
        savedConnections.removeAll { $0.id == connection.id }
        store.save(savedConnections)
    }

    func moveConnection(from source: IndexSet, to destination: Int) {
        savedConnections.move(fromOffsets: source, toOffset: destination)
        store.save(savedConnections)
    }

    // MARK: - SSH Actions

    func connect(_ connection: SSHConnection) {
        lastError = nil
        backgroundQueue.async { [weak self] in
            guard let self else { return }
            if self.monitor.launchSSH(connection: connection) != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.refreshProcesses()
                }
            } else {
                DispatchQueue.main.async {
                    self.lastError = "Failed to launch SSH connection"
                }
            }
        }
    }

    func connectBackground(_ connection: SSHConnection) {
        lastError = nil
        backgroundQueue.async { [weak self] in
            guard let self else { return }
            if self.monitor.launchSSHBackground(connection: connection) != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.refreshProcesses()
                }
            } else {
                DispatchQueue.main.async {
                    self.lastError = "Failed to launch background SSH connection"
                }
            }
        }
    }

    func disconnect(process: SSHProcess) {
        lastError = nil
        let pid = process.pid
        backgroundQueue.async { [weak self] in
            _ = self?.monitor.terminateProcess(pid: pid)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.refreshProcesses()
            }
        }
    }

    func disconnectAll() {
        let pids = activeProcesses.map { $0.pid }
        backgroundQueue.async { [weak self] in
            for pid in pids {
                _ = self?.monitor.terminateProcess(pid: pid)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.refreshProcesses()
            }
        }
    }

    func isConnected(_ connection: SSHConnection) -> Bool {
        activeProcesses.contains { $0.matchedConnectionID == connection.id }
    }

    func processFor(_ connection: SSHConnection) -> SSHProcess? {
        activeProcesses.first { $0.matchedConnectionID == connection.id }
    }

    func registerProcess(_ process: SSHProcess, name: String) {
        let connection = SSHConnection(
            name: name,
            host: process.host,
            user: process.user,
            port: process.port,
            localForwards: process.localForwards,
            noRemoteCommand: process.hasNoRemoteCommand
        )
        addConnection(connection)
        refreshProcesses()
    }
}

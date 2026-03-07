import Foundation
import Combine
import SwiftUI

final class SSHManager: ObservableObject {
    @Published var savedConnections: [SSHConnection] = []
    @Published var activeProcesses: [SSHProcess] = []
    @Published var lastError: String?

    private let store = ConnectionStore()
    private let monitor = ProcessMonitor()
    private var timer: Timer?

    var activeCount: Int {
        activeProcesses.count
    }

    var matchedProcesses: [SSHProcess] {
        activeProcesses.filter { $0.matchedConnectionID != nil }
    }

    var unmatchedProcesses: [SSHProcess] {
        activeProcesses.filter { $0.matchedConnectionID == nil }
    }

    var disconnectedConnections: [SSHConnection] {
        let activeIDs = Set(activeProcesses.compactMap { $0.matchedConnectionID })
        return savedConnections.filter { !activeIDs.contains($0.id) }
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
        var processes = monitor.fetchSSHProcesses()

        for i in processes.indices {
            if let match = findMatchingConnection(for: processes[i]) {
                processes[i].matchedConnectionID = match.id
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.activeProcesses = processes
        }
    }

    private func findMatchingConnection(for process: SSHProcess) -> SSHConnection? {
        savedConnections.first { conn in
            let hostMatch = conn.host == process.host
            let userMatch = conn.user.isEmpty || conn.user == process.user
            let portMatch = conn.port == process.port
            return hostMatch && userMatch && portMatch
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
        if monitor.launchSSH(connection: connection) != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.refreshProcesses()
            }
        } else {
            lastError = "Failed to launch SSH connection"
        }
    }

    func disconnect(process: SSHProcess) {
        lastError = nil
        if monitor.terminateProcess(pid: process.pid) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.refreshProcesses()
            }
        }
    }

    func disconnectAll() {
        for process in activeProcesses {
            _ = monitor.terminateProcess(pid: process.pid)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshProcesses()
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
            port: process.port
        )
        addConnection(connection)
        refreshProcesses()
    }
}
